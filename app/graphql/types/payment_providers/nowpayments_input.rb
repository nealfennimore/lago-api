# frozen_string_literal: true

module Types
  module PaymentProviders
    class NowpaymentsInput < BaseInputObject
      description 'Nowpayments input arguments'

      argument :api_key, String, required: true
      argument :code, String, required: true
      argument :hmac_key, String, required: false
      argument :name, String, required: true
      argument :success_redirect_url, String, required: false
    end
  end
end
