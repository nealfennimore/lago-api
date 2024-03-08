# frozen_string_literal: true

module Mutations
  module PaymentProviders
    module Nowpayments
      class Create < Base
        graphql_name 'AddNowpaymentsPaymentProvider'
        description 'Add Nowpayments payment provider'

        input_object_class Types::PaymentProviders::NowpaymentsInput

        type Types::PaymentProviders::Nowpayments
      end
    end
  end
end
