# frozen_string_literal: true

module Mutations
  module PaymentProviders
    module Nowpayments
      class Update < Base
        graphql_name 'UpdateNowpaymentsPaymentProvider'
        description 'Update Nowpayments payment provider'

        input_object_class Types::PaymentProviders::NowpaymentsUpdateInput

        type Types::PaymentProviders::Nowpayments
      end
    end
  end
end
