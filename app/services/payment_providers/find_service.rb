# frozen_string_literal: true

module PaymentProviders
  class FindService < BaseService
    attr_reader :id, :code, :organization_id, :payment_provider_type, :scope

    def initialize(organization_id:, code: nil, id: nil, payment_provider_type: nil)
      @id = id
      @code = code
      @organization_id = organization_id
      @payment_provider_type = payment_provider_type
      @scope = PaymentProviders::BaseProvider.where(organization_id:)

      if payment_provider_type.present?
        cls = if payment_provider_type == 'nowpayments'
          payment_provider_type.capitalize
        else
          payment_provider_type.classify
        end

        @scope = @scope.where(type: "PaymentProviders::#{cls}Provider")
      end

      super(nil)
    end

    def call
      if id.present? && (payment_provider = scope.find_by(id:))
        result.payment_provider = payment_provider
        return result
      end

      if code.blank? && scope.count > 1
        return result.service_failure!(
          code: 'payment_provider_code_missing',
          message: 'Code is missing',
        )
      end

      @scope = scope.where(code:) if code.present?

      unless scope.exists?
        return result.service_failure!(code: 'payment_provider_not_found', message: 'Payment provider not found')
      end

      result.payment_provider = scope.first
      result
    end
  end
end
