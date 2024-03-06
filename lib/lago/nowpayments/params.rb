# frozen_string_literal: true

module Lago
  module Nowpayments
    class Params
      attr_reader :params

      def initialize(params = {})
        @params = params.to_h
      end

      def to_h
        default_params.merge(params)
      end

      private

      def default_params
        {}
      end
    end
  end
end
