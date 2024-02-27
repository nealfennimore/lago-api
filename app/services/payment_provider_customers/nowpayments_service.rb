# frozen_string_literal: true

module PaymentProviderCustomers
  class NowPaymentsService < BaseService
    include Lago::NowPayments::ErrorHandlable
    include Customers::PaymentProviderFinder

    def initialize(nowpayments_customer = nil)
      @nowpayments_customer = nowpayments_customer

      super(nil)
    end

    def create
      result.nowpayments_customer = nowpayments_customer
      return result if nowpayments_customer.provider_customer_id?

      checkout_url_result = generate_checkout_url
      return result unless checkout_url_result.success?

      result.checkout_url = checkout_url_result.checkout_url
      result
    end

    def update
      result
    end

    def generate_checkout_url(send_webhook: true)
      return result.not_found_failure!(resource: 'nowpayments_payment_provider') unless nowpayments_payment_provider

      res = client.checkout.payment_links_api.payment_links(Lago::NowPayments::Params.new(payment_link_params).to_h)
      nowpayments_success, nowpayments_error = handle_nowpayments_response(res)
      result.service_failure!(code: nowpayments_error.code, message: nowpayments_error.msg) unless nowpayments_success
      return result unless result.success?

      result.checkout_url = res.response['url']

      if send_webhook
        SendWebhookJob.perform_later(
          'customer.checkout_url_generated',
          customer,
          checkout_url: result.checkout_url,
        )
      end

      result
    rescue NowPayments::NowPaymentsError => e
      deliver_error_webhook(e)

      raise
    end

    def preauthorise(organization, event)
      shopper_reference = shopper_reference_from_event(event)
      payment_method_id = event.dig('additionalData', 'recurring.recurringDetailReference')

      @nowpayments_customer = PaymentProviderCustomers::NowPaymentsCustomer
        .joins(:customer)
        .where(customers: { external_id: shopper_reference, organization_id: organization.id })
        .first

      return handle_missing_customer(shopper_reference) unless nowpayments_customer

      if event['success'] == 'true'
        nowpayments_customer.update!(payment_method_id:, provider_customer_id: shopper_reference)

        if organization.webhook_endpoints.any?
          SendWebhookJob.perform_later('customer.payment_provider_created', customer)
        end
      else
        deliver_error_webhook(NowPayments::NowPaymentsError.new(nil, nil, event['reason'], event['eventCode']))
      end

      result.nowpayments_customer = nowpayments_customer
      result
    end

    private

    attr_accessor :nowpayments_customer

    delegate :customer, to: :nowpayments_customer

    def organization
      @organization ||= customer.organization
    end

    def nowpayments_payment_provider
      @nowpayments_payment_provider ||= payment_provider(customer)
    end

    def client
      @client ||= NowPayments::Client.new(
        api_key: nowpayments_payment_provider.api_key,
        env: nowpayments_payment_provider.environment,
        live_url_prefix: nowpayments_payment_provider.live_prefix,
      )
    end

    def shopper_reference_from_event(event)
      event.dig('additionalData', 'shopperReference') ||
        event.dig('additionalData', 'recurring.shopperReference')
    end

    def payment_link_params
      prms = {
        reference: "authorization customer #{customer.external_id}",
        amount: {
          value: 0, # pre-authorization
          currency: customer.currency.presence || 'USD',
        },
        merchantAccount: nowpayments_payment_provider.merchant_account,
        returnUrl: success_redirect_url,
        shopperReference: customer.external_id,
        storePaymentMethodMode: 'enabled',
        recurringProcessingModel: 'UnscheduledCardOnFile',
        expiresAt: Time.current + 69.days,
      }
      prms[:shopperEmail] = customer.email&.strip&.split(',')&.first if customer.email
      prms
    end

    def success_redirect_url
      nowpayments_payment_provider.success_redirect_url.presence || PaymentProviders::NowPaymentsProvider::SUCCESS_REDIRECT_URL
    end

    def deliver_error_webhook(nowpayments_error)
      return unless organization.webhook_endpoints.any?

      SendWebhookJob.perform_later(
        'customer.payment_provider_error',
        customer,
        provider_error: {
          message: nowpayments_error.request&.dig('msg') || nowpayments_error.msg,
          error_code: nowpayments_error.request&.dig('code') || nowpayments_error.code,
        },
      )
    end

    def handle_missing_customer(shopper_reference)
      # NOTE: NowPayments customer was not created from lago
      return result unless shopper_reference

      # NOTE: Customer does not belong to this lago instance
      return result if Customer.find_by(external_id: shopper_reference).nil?

      result.not_found_failure!(resource: 'nowpayments_customer')
    end
  end
end
