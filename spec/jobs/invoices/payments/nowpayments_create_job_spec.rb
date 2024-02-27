# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Invoices::Payments::NowPaymentsCreateJob, type: :job do
  let(:invoice) { create(:invoice) }

  let(:nowpayments_service) { instance_double(Invoices::Payments::NowPaymentsService) }

  it 'calls the stripe create service' do
    allow(Invoices::Payments::NowPaymentsService).to receive(:new)
      .with(invoice)
      .and_return(nowpayments_service)
    allow(nowpayments_service).to receive(:create)
      .and_return(BaseService::Result.new)

    described_class.perform_now(invoice)

    expect(Invoices::Payments::NowPaymentsService).to have_received(:new)
    expect(nowpayments_service).to have_received(:create)
  end
end
