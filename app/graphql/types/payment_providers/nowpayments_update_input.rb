# frozen_string_literal: true

module Types
  module PaymentProviders
    class NowpaymentsUpdateInput < BaseInputObject
      description 'Nowpayments update input arguments'

      argument :cancel_redirect_url, String, required: false
      argument :code, String, required: false
      argument :id, ID, required: true
      argument :ipn_callback_url, String, required: false
      argument :name, String, required: false
      argument :partially_paid_redirect_url, String, required: false
      argument :success_redirect_url, String, required: false
    end
  end
end
