# frozen_string_literal: true

require 'net/http/post/multipart'

module Lago
  module Nowpayments
    class ClientResponse
      def initialize(code:, message:, body:)
        @code = code
        @message = message
        @body = body
      end

      attr_reader :code, :message, :body

      def status
        code.to_i
      end

      def response
        JSON.parse(body) if body
      end
    end

    class Client
      def initialize(api_key: nil)
        @api_key = api_key
      end

      def create_invoice(payload:)
        res = LagoHttpClient::Client.new('https://api-sandbox.nowpayments.io/v1/invoice').post_with_response(
          payload,
          api_key_header,
        )
        handle_success(res)
      rescue ::LagoHttpClient::HttpError => e
        handle_failure(e)
      end

      def create_payment_by_invoice(payload:)
        res = LagoHttpClient::Client.new('https://api-sandbox.nowpayments.io/v1/invoice').post_with_response(
          payload,
          api_key_header,
        )
        handle_success(res)
      rescue ::LagoHttpClient::HttpError => e
        handle_failure(e)
      end

      def get_status(payment_id:)
        res = LagoHttpClient::Client.new("https://api-sandbox.nowpayments.io/v1/payment#{payment_id}").get(
          api_key_header,
        )
        handle_success(res)
      rescue ::LagoHttpClient::HttpError => e
        handle_failure(e)
      end

      private

      def handle_success(response)
        ClientResponse.new(
          code: response.code,
          message: response.message,
          body: response.body,
        )
      end

      def handle_failure(response)
        ClientResponse.new(
          code: response.error_code,
          message: response.message,
          body: nil,
        )
      end

      def api_key_header
        { "x-api-key": @api_key }
      end
    end
  end
end
