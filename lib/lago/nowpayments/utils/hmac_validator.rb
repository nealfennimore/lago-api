module Lago
  module Nowpayments
    module Utils
      class HmacValidator
        HMAC_ALGORITHM = 'sha512'.freeze

        def valid_notification_hmac?(signature, payload, hmac_key)
          expected_sign = calculate_notification_hmac(payload, hmac_key)
          expected_sign == signature
        end

        def calculate_notification_hmac(payload, hmac_key)
          data = sort_hash(payload).to_json
          OpenSSL::HMAC.hexdigest(HMAC_ALGORITHM, hmac_key, data)
        end

        private

        def sort_hash(hash)
          hash.sort.to_h.map do |key, value|
            if value.is_a?(Hash)
              [key, sort_hash(value)]
            else
              [key, value]
            end
          end.to_h
        end
      end
    end
  end
end
