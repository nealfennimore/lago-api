# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreditNotes::Refunds::NowpaymentsCreateJob, type: :job do
  let(:credit_note) { create(:credit_note) }

  let(:refund_service) do
    instance_double(CreditNotes::Refunds::NowpaymentsService)
  end

  it 'delegates to the nowpayments refund service' do
    allow(CreditNotes::Refunds::NowpaymentsService).to receive(:new)
      .with(credit_note)
      .and_return(refund_service)
    allow(refund_service).to receive(:create)
      .and_return(BaseService::Result.new)

    described_class.perform_now(credit_note)

    expect(CreditNotes::Refunds::NowpaymentsService).to have_received(:new)
    expect(refund_service).to have_received(:create)
  end
end
