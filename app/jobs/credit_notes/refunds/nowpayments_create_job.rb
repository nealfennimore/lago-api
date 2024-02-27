# frozen_string_literal: true

module CreditNotes
  module Refunds
    class NowPaymentsCreateJob < ApplicationJob
      queue_as 'providers'

      def perform(credit_note)
        result = CreditNotes::Refunds::NowPaymentsService.new(credit_note).create
        result.raise_if_error!
      end
    end
  end
end
