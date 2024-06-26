# frozen_string_literal: true

module Lago
  module Nowpayments
    module ErrorHandlable
      def handle_nowpayments_response(res)
        return [true, nil] if res.status < 400

        code = res.status
        message = res.message

        error = NowpaymentsError.new(nil, nil, message, code)
        deliver_error_webhook(error)

        [false, error]
      end
    end
  end
end
