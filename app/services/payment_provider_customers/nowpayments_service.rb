# frozen_string_literal: true

module PaymentProviderCustomers
  class NowpaymentsService < BaseService
    include Lago::Nowpayments::ErrorHandlable
    include Customers::PaymentProviderFinder

    def initialize(nowpayments_customer = nil)
      @nowpayments_customer = nowpayments_customer

      super(nil)
    end

    def create
      result.nowpayments_customer = nowpayments_customer
      return result if nowpayments_customer.provider_customer_id?

      nowpayments_customer.update!(
        provider_customer_id: customer.id,
      )

      deliver_success_webhook
      # PaymentProviderCustomers::NowpaymentsCheckoutUrlJob.perform_later(nowpayments_customer)

      result.nowpayments_customer = nowpayments_customer
      result
    end

    def update
      result
    end

    def generate_checkout_url(send_webhook: true)
      response = client.create_invoice # TODO: No payload but might remove as is preauth
      result.checkout_url = response.invoice_url

      if send_webhook
        SendWebhookJob.perform_later(
          'customer.checkout_url_generated',
          customer,
          checkout_url: result.checkout_url,
        )
      end

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
      @client || Lago::Nowpayments::Client.new(
        api_key: nowpayments_payment_provider.api_key,
        api_site: nowpayments_payment_provider.api_site,
      )
    end

    def deliver_success_webhook
      return unless organization.webhook_endpoints.any?

      SendWebhookJob.perform_later(
        'customer.payment_provider_created',
        customer,
      )
    end

    def deliver_error_webhook(nowpayments_error)
      return unless organization.webhook_endpoints.any?

      SendWebhookJob.perform_later(
        'customer.payment_provider_error',
        customer,
        provider_error: {
          message: nowpayments_error.message,
          error_code: nowpayments_error.code,
        },
      )
    end

    def success_redirect_url
      nowpayments_payment_provider.success_redirect_url.presence ||
        PaymentProviders::NowpaymentsProvider::SUCCESS_REDIRECT_URL
    end
  end
end
