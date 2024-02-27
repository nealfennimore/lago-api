# frozen_string_literal: true

module PaymentProviderCustomers
  class NowPaymentsCheckoutUrlJob < ApplicationJob
    queue_as :providers

    retry_on NowPayments::NowPaymentsError, wait: :exponentially_longer, attempts: 6
    retry_on ActiveJob::DeserializationError

    def perform(nowpayments_customer)
      result = PaymentProviderCustomers::NowPaymentsService.new(nowpayments_customer).generate_checkout_url
      result.raise_if_error!
    end
  end
end
