# frozen_string_literal: true

module PaymentProviderCustomers
  class NowpaymentsCreateJob < ApplicationJob
    queue_as :providers

    retry_on Lago::Nowpayments::NowpaymentsError, wait: :exponentially_longer, attempts: 6
    retry_on ActiveJob::DeserializationError

    def perform(nowpayments_customer)
      result = PaymentProviderCustomers::NowpaymentsService.new(nowpayments_customer).create
      result.raise_if_error!
    end
  end
end
