# frozen_string_literal: true

module PaymentProviders
  class NowPaymentsService < BaseService
    WEBHOOKS_EVENTS = %w[AUTHORISATION REFUND REFUND_FAILED].freeze

    def create_or_update(**args)
      payment_provider_result = PaymentProviders::FindService.call(
        organization_id: args[:organization].id,
        code: args[:code],
        id: args[:id],
        payment_provider_type: 'nowpayments',
      )

      nowpayments_provider = if payment_provider_result.success?
        payment_provider_result.payment_provider
      else
        PaymentProviders::NowPaymentsProvider.new(
          organization_id: args[:organization].id,
          code: args[:code],
        )
      end

      api_key = nowpayments_provider.api_key

      nowpayments_provider.api_key = args[:api_key] if args.key?(:api_key)
      nowpayments_provider.code = args[:code] if args.key?(:code)
      nowpayments_provider.name = args[:name] if args.key?(:name)
      nowpayments_provider.merchant_account = args[:merchant_account] if args.key?(:merchant_account)
      nowpayments_provider.live_prefix = args[:live_prefix] if args.key?(:live_prefix)
      nowpayments_provider.hmac_key = args[:hmac_key] if args.key?(:hmac_key)
      nowpayments_provider.success_redirect_url = args[:success_redirect_url] if args.key?(:success_redirect_url)
      nowpayments_provider.save!

      if api_key != nowpayments_provider.api_key
        # NOTE: ensure existing payment_provider_customers are
        #       attached to the provider
        reattach_provider_customers(
          organization_id: args[:organization_id],
          nowpayments_provider:,
        )
      end

      result.nowpayments_provider = nowpayments_provider
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    def handle_incoming_webhook(organization_id:, body:, code: nil)
      organization = Organization.find_by(id: organization_id)
      return result.service_failure!(code: 'webhook_error', message: 'Organization not found') unless organization

      payment_provider_result = PaymentProviders::FindService.call(
        organization_id:,
        code:,
        payment_provider_type: 'nowpayments',
      )

      return payment_provider_result unless payment_provider_result.success?

      validator = ::NowPayments::Utils::HmacValidator.new
      hmac_key = payment_provider_result.payment_provider.hmac_key

      if hmac_key && !validator.valid_notification_hmac?(body, hmac_key)
        return result.service_failure!(code: 'webhook_error', message: 'Invalid signature')
      end

      PaymentProviders::NowPayments::HandleEventJob.perform_later(organization:, event_json: body.to_json)

      result.event = body
      result
    end

    def handle_event(organization:, event_json:)
      event = JSON.parse(event_json)
      unless WEBHOOKS_EVENTS.include?(event['eventCode'])
        return result.service_failure!(
          code: 'webhook_error',
          message: "Invalid nowpayments event code: #{event['eventCode']}",
        )
      end

      case event['eventCode']
      when 'AUTHORISATION'
        amount = event.dig('amount', 'value')
        payment_type = event.dig('additionalData', 'metadata.payment_type')

        if payment_type == 'one-time'
          update_result = update_payment_status(event, payment_type)
          return update_result.raise_if_error! || update_result
        end

        return result if amount != 0

        service = PaymentProviderCustomers::NowPaymentsService.new

        result = service.preauthorise(organization, event)
        result.raise_if_error! || result
      when 'REFUND'
        service = CreditNotes::Refunds::NowPaymentsService.new

        provider_refund_id = event['pspReference']
        status = (event['success'] == 'true') ? :succeeded : :failed

        result = service.update_status(provider_refund_id:, status:)
        result.raise_if_error! || result
      when 'REFUND_FAILED'
        return result if event['success'] != 'true'

        service = CreditNotes::Refunds::NowPaymentsService.new

        provider_refund_id = event['pspReference']

        result = service.update_status(provider_refund_id:, status: :failed)
        result.raise_if_error! || result
      end
    end

    def reattach_provider_customers(organization_id:, nowpayments_provider:)
      PaymentProviderCustomers::NowPaymentsCustomer
        .joins(:customer)
        .where(payment_provider_id: nil, customers: { organization_id: }).each do |c|
          c.update(payment_provider_id: nowpayments_provider.id)
        end
    end

    private

    def update_payment_status(event, payment_type)
      provider_payment_id = event['pspReference']
      status = (event['success'] == 'true') ? 'succeeded' : 'failed'
      metadata = { payment_type:, lago_invoice_id: event.dig('additionalData', 'metadata.lago_invoice_id') }

      Invoices::Payments::NowPaymentsService.new.update_payment_status(provider_payment_id:, status:, metadata:)
    end
  end
end
