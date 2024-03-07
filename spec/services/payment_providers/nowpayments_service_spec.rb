# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentProviders::NowpaymentsService, type: :service do
  subject(:nowpayments_service) { described_class.new(membership.user) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:api_key) { 'test_api_key_1' }
  let(:code) { 'code_1' }
  let(:name) { 'Name 1' }
  let(:hmac_key) { 'y8I/Ub4BOetEDyQloPcdq106DWse80GI' }
  let(:success_redirect_url) { Faker::Internet.url }

  describe '.create_or_update' do
    it 'creates a nowpayments provider' do
      expect do
        nowpayments_service.create_or_update(
          organization:,
          api_key:,
          code:,
          name:,
          success_redirect_url:,
        )
      end.to change(PaymentProviders::NowpaymentsProvider, :count).by(1)
    end

    context 'when organization already have a nowpayments provider' do
      let(:nowpayments_provider) do
        create(:nowpayments_provider, organization:, api_key: 'api_key_123', code:)
      end

      before { nowpayments_provider }

      it 'updates the existing provider' do
        result = nowpayments_service.create_or_update(
          organization:,
          api_key:,
          code:,
          name:,
          success_redirect_url:,
        )

        expect(result).to be_success

        aggregate_failures do
          expect(result.nowpayments_provider.id).to eq(nowpayments_provider.id)
          expect(result.nowpayments_provider.api_key).to eq('test_api_key_1')
          expect(result.nowpayments_provider.code).to eq(code)
          expect(result.nowpayments_provider.name).to eq(name)
          expect(result.nowpayments_provider.success_redirect_url).to eq(success_redirect_url)
        end
      end
    end

    context 'with validation error' do
      let(:api_key) { nil }

      it 'returns an error result' do
        result = nowpayments_service.create_or_update(
          organization:,
          api_key:,
        )

        aggregate_failures do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:api_key]).to eq(['value_is_mandatory'])
          expect(result.error.messages[:name]).to eq(['value_is_mandatory'])
        end
      end
    end
  end

  describe '.handle_incoming_webhook' do
    let(:nowpayments_provider) { create(:nowpayments_provider, organization:, hmac_key:) }

    let(:event) do
      path = Rails.root.join('spec/fixtures/nowpayments/webhook_payment_response.json')
      JSON.parse(File.read(path))
    end

    before { nowpayments_provider }

    it 'checks the webhook' do
      result = nowpayments_service.handle_incoming_webhook(
        organization_id: organization.id,
        body: event,
        signature: 'ab7a19515eb00931620a73d51ef9b7f5171068844a695214ad51406130331b2e2dbd1ceeee7a75b328a4d485ead7bd41094b8f5a6f5dcbc8193b4fcd9ad21088',
      )

      expect(result).to be_success
      expect(PaymentProviders::Nowpayments::HandleEventJob).to have_been_enqueued
    end

    context 'when failing to validate the signature' do
      it 'returns an error' do
        result = nowpayments_service.handle_incoming_webhook(
          organization_id: organization.id,
          body: event,
          signature: 'signature',
        )

        aggregate_failures do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ServiceFailure)
          expect(result.error.code).to eq('webhook_error')
          expect(result.error.error_message).to eq('Invalid signature')
        end
      end
    end
  end

  describe '.handle_event' do
    let(:payment_service) { instance_double(Invoices::Payments::NowpaymentsService) }
    let(:service_result) { BaseService::Result.new }

    before do
      allow(Invoices::Payments::NowpaymentsService).to receive(:new)
        .and_return(payment_service)
      allow(payment_service).to receive(:update_payment_status)
        .and_return(service_result)
    end

    context 'when succeeded payment event' do
      let(:event) do
        path = Rails.root.join('spec/fixtures/nowpayments/webhook_payment_response.json')
        File.read(path)
      end

      it 'routes the event to an other service' do
        nowpayments_service.handle_event(organization:, event_json: event)

        expect(Invoices::Payments::NowpaymentsService).to have_received(:new)
        expect(payment_service).to have_received(:update_payment_status)
      end
    end

    context 'when succeeded refund event' do
      let(:refund_service) { instance_double(CreditNotes::Refunds::NowpaymentsService) }
      let(:event) do
        path = Rails.root.join('spec/fixtures/nowpayments/webhook_payment_response_refund.json')
        File.read(path)
      end

      before do
        allow(CreditNotes::Refunds::NowpaymentsService).to receive(:new)
          .and_return(refund_service)
        allow(refund_service).to receive(:update_status)
          .and_return(service_result)
      end

      it 'routes the event to an other service' do
        nowpayments_service.handle_event(organization:, event_json: event)

        expect(CreditNotes::Refunds::NowpaymentsService).to have_received(:new)
        expect(refund_service).to have_received(:update_status)
      end
    end
  end
end
