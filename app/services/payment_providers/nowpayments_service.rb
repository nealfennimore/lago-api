# frozen_string_literal: true

module PaymentProviders
  class NowpaymentsService < BaseService
    WEBHOOKS_EVENTS = %w[waiting confirming confirmed sending partially_paid finished failed refunded expired].freeze

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
        PaymentProviders::NowpaymentsProvider.new(
          organization_id: args[:organization].id,
          code: args[:code],
        )
      end

      nowpayments_provider.api_key = args[:api_key] if args.key?(:api_key)
      nowpayments_provider.code = args[:code] if args.key?(:code)
      nowpayments_provider.name = args[:name] if args.key?(:name)
      nowpayments_provider.hmac_key = args[:hmac_key] if args.key?(:hmac_key)
      nowpayments_provider.success_redirect_url = args[:success_redirect_url] if args.key?(:success_redirect_url)
      nowpayments_provider.ipn_callback_url = args[:ipn_callback_url] if args.key?(:ipn_callback_url)
      nowpayments_provider.cancel_redirect_url = args[:cancel_redirect_url] if args.key?(:cancel_redirect_url)
      if args.key?(:partially_paid_redirect_url)
        nowpayments_provider.partially_paid_redirect_url = args[:partially_paid_redirect_url]
      end
      nowpayments_provider.save!

      result.nowpayments_provider = nowpayments_provider
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    def handle_incoming_webhook(organization_id:, body:, signature:, code: nil)
      organization = Organization.find_by(id: organization_id)
      return result.service_failure!(code: 'webhook_error', message: 'Organization not found') unless organization

      payment_provider_result = PaymentProviders::FindService.call(
        organization_id:,
        code:,
        payment_provider_type: 'nowpayments',
      )

      return payment_provider_result unless payment_provider_result.success?

      validator = Lago::Nowpayments::Utils::HmacValidator.new
      hmac_key = payment_provider_result.payment_provider.hmac_key

      if hmac_key && !validator.valid_notification_hmac?(signature, body, hmac_key)
        return result.service_failure!(code: 'webhook_error', message: 'Invalid signature')
      end

      PaymentProviders::Nowpayments::HandleEventJob.perform_later(organization:, event_json: body)

      result.event = body
      result
    end

    def handle_event(organization:, event_json:)
      event = JSON.parse(event_json)

      unless WEBHOOKS_EVENTS.include?(event['payment_status'])
        return result.service_failure!(
          code: 'webhook_error',
          message: "Invalid nowpayments payment status: #{event['payment_status']}",
        )
      end

      case event['payment_status']
      when 'finished'
        provider_payment_id = event['invoice_id']
        puts(provider_payment_id)
        service = Invoices::Payments::NowpaymentsService.new
        result = service.update_payment_status(provider_payment_id:, status: :succeeded)
        return result.raise_if_error! || result
      when 'refunded'
        provider_refund_id = event['invoice_id']
        service = CreditNotes::Refunds::NowpaymentsService.new
        result = service.update_status(provider_refund_id:, status: :succeeded)
        return result.raise_if_error! || result
      when 'failed', 'expired'
        provider_refund_id = event['invoice_id']
        service = Invoices::Payments::NowpaymentsService.new
        result = service.update_payment_status(provider_refund_id:, status: :failed)
        return result.raise_if_error! || result

      end

      result.raise_if_error! || result
    end

    private

    def update_payment_status(event, payment_type)
      provider_payment_id = event['payment_id']
      status = event['payment_status']
      metadata = { payment_type:, lago_invoice_id: event['payment_id'] }

      Invoices::Payments::NowpaymentsService.new.update_payment_status(provider_payment_id:, status:, metadata:)
    end
  end
end
