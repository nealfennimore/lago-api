# frozen_string_literal: true

require 'net/http/post/multipart'

module Lago
  module Nowpayments
    class Client
      def create_invoice(payload:)
        response = LagoHttpClient.new('https://api-sandbox.nowpayments.io/v1/invoice').post(
          payload,
          api_key_header,
        )

        return response unless response.failure?

        handle_failure(response)
      end

      def create_payment_by_invoice(payload:)
        response = LagoHttpClient.new('https://api-sandbox.nowpayments.io/v1/invoice').post(
          payload,
          api_key_header,
        )

        return response unless response.failure?

        handle_failure(response)
      end

      def get_status(payment_id:)
        response = LagoHttpClient.new("https://api-sandbox.nowpayments.io/v1/payment#{payment_id}").get(
          api_key_header,
        )

        return response unless response.failure?

        handle_failure(response)
      end

      private

      def handle_failure(response:)
        APIError.new(
          code: response['code'],
          message: response['message'],
          response:,
        )
      end

      def api_key
        @api_key ||= nowpayments_payment_provider.api_key
      end

      def api_key_header
        { "x-api-key": api_key }
      end
    end
  end
end
