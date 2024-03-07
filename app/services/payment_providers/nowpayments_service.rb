# frozen_string_literal: true

module PaymentProviders
  class NowpaymentsService < BaseService
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

      PaymentProviders::Nowpayments::HandleEventJob.perform_later(organization:, event_json: body.to_json)

      result.event = body
      result
    end

    def handle_event(organization:, event_json:)
      event = JSON.parse(event_json)

      payment_type = event.dig('additionalData', 'metadata.payment_type')

      if payment_type == 'one-time'
        update_result = update_payment_status(event, payment_type)
        return update_result.raise_if_error! || update_result
      end

      return result if amount != 0

      # TODO: Handle events

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
