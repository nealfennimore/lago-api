# frozen_string_literal: true

module PaymentProviders
  class NowpaymentsProvider < BaseProvider
    SUCCESS_REDIRECT_URL = 'https://www.nowpayments.com/'

    validates :api_key, presence: true
    validates :success_redirect_url, nowpayments_url: true, allow_nil: true, length: { maximum: 1024 }

    def environment
      if Rails.env.production?
        :live
      else
        :test
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
  end
end
