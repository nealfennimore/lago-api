# frozen_string_literal: true

module PaymentProviders
  class NowpaymentsProvider < BaseProvider
    SUCCESS_REDIRECT_URL = 'https://www.nowpayments.com/'

    validates :api_key, presence: true
    validates :success_redirect_url, nowpayments_url: true, allow_nil: true, length: { maximum: 1024 }

    def environment
      if Rails.env.production? and ENV['NOWPAYMENTS_ENV'] != 'sandbox'
        :live
      else
        :test
      end
    end

    def api_site
      if environment == :live
        'https://api.nowpayments.io'
      else
        'https://api-sandbox.nowpayments.io'
      end
    end

    def auth_site
      if environment == :live
        'https://nowpayments.io'
      else
        'https://sandbox.nowpayments.io'
      end
    end

    def api_key=(value)
      push_to_secrets(key: 'api_key', value:)
    end

    def api_key
      get_from_secrets('api_key')
    end

    def hmac_key=(value)
      push_to_secrets(key: 'hmac_key', value:)
    end

    def hmac_key
      get_from_secrets('hmac_key')
    end

    def cancel_redirect_url=(value)
      push_to_settings(key: 'cancel_redirect_url', value:)
    end

    def cancel_redirect_url
      get_from_settings('cancel_redirect_url')
    end

    def partially_paid_redirect_url=(value)
      push_to_settings(key: 'partially_paid_redirect_url', value:)
    end

    def partially_paid_redirect_url
      get_from_settings('partially_paid_redirect_url')
    end

    def ipn_callback_url=(value)
      push_to_settings(key: 'ipn_callback_url', value:)
    end

    def ipn_callback_url
      get_from_settings('ipn_callback_url') || default_ipn_callback_url
    end

    private

    def default_ipn_callback_url
      "#{ENV['LAGO_API_URL']}/webhooks/nowpayments/#{organization_id}"
    end
  end
end
