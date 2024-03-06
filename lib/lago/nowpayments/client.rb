# frozen_string_literal: true

require 'net/http/post/multipart'

module Lago
  module Nowpayments
    class Client
      def make_invoice
        LagoHttpClient.new('https://api-sandbox.nowpayments.io/v1/invoice').post(
          payload,
          api_key_header,
        )
      end

      private

      def api_key
        @api_key ||= nowpayments_payment_provider.api_key
      end

      def api_key_header
        { "x-api-key": api_key }
      end
    end
  end
end
