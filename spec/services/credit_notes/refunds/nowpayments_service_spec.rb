# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreditNotes::Refunds::NowpaymentsService, type: :service do
  subject(:nowpayments_service) { described_class.new(credit_note) }

  let(:customer) { create(:customer, payment_provider_code: code) }
  let(:organization) { customer.organization }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:nowpayments_payment_provider) { create(:nowpayments_provider, organization:, code:) }
  let(:nowpayments_customer) { create(:nowpayments_customer, customer:) }
  let(:nowpayments_client) { instance_double(Lago::Nowpayments::Client) }
  # let(:modifications_api) { Nowpayments::ModificationsApi.new(nowpayments_client, 70) }
  # let(:checkout) { Nowpayments::Checkout.new(nowpayments_client, 70) }
  let(:refunds_response) { generate(:nowpayments_refunds_response) }
  let(:code) { 'nowpayments_1' }
  let(:payment) do
    create(
      :payment,
      payment_provider: nowpayments_payment_provider,
      payment_provider_customer: nowpayments_customer,
      amount_cents: 200,
      amount_currency: 'CHF',
      invoice: credit_note.invoice,
    )
  end

  let(:credit_note) do
    create(
      :credit_note,
      customer:,
      invoice:,
      refund_amount_cents: 134,
      refund_amount_currency: 'CHF',
      refund_status: :pending,
    )
  end

  describe '#create' do
    before do
      payment

      allow(Lago::Nowpayments::Client).to receive(:new)
        .and_return(nowpayments_client)
      # allow(nowpayments_client).to receive(:checkout)
        # .and_return(checkout)
      # allow(checkout).to receive(:modifications_api)
        # .and_return(modifications_api)
      allow(modifications_api).to receive(:refund_captured_payment)
        .and_return(refunds_response)
      allow(SegmentTrackJob).to receive(:perform_later)
    end

    xit 'creates a nowpayments refund and a refund' do
      result = nowpayments_service.create

      aggregate_failures do
        expect(result).to be_success

        expect(result.refund.id).to be_present

        expect(result.refund.credit_note).to eq(credit_note)
        expect(result.refund.payment).to eq(payment)
        expect(result.refund.payment_provider).to eq(nowpayments_payment_provider)
        expect(result.refund.payment_provider_customer).to eq(nowpayments_customer)
        expect(result.refund.amount_cents).to eq(134)
        expect(result.refund.amount_currency).to eq('CHF')
        expect(result.refund.status).to eq('pending')
        expect(result.refund.provider_refund_id).to eq(refunds_response.response['pspReference'])

        expect(result.credit_note).not_to be_succeeded
        expect(result.credit_note.refunded_at).not_to be_present
      end
    end

    xit 'call SegmentTrackJob' do
      nowpayments_service.create

      expect(SegmentTrackJob).to have_received(:perform_later).with(
        membership_id: CurrentContext.membership,
        event: 'refund_status_changed',
        properties: {
          organization_id: credit_note.organization.id,
          credit_note_id: credit_note.id,
          refund_status: 'pending',
        },
      )
    end

    context 'with an error on nowpayments' do
      before do
        allow(modifications_api).to receive(:refund_captured_payment)
          .and_raise(Lago::Nowpayments::NowpaymentsError.new(nil, nil, 'error'))
      end

      xit 'delivers an error webhook' do
        expect { nowpayments_service.create }
          .to raise_error(Lago::Nowpayments::NowpaymentsError)

        expect(SendWebhookJob).to have_been_enqueued
          .with(
            'credit_note.provider_refund_failure',
            credit_note,
            provider_customer_id: nowpayments_customer.provider_customer_id,
            provider_error: {
              message: 'error',
              error_code: nil,
            },
          )
      end
    end

    context 'when credit note does not have a refund amount' do
      let(:credit_note) do
        create(
          :credit_note,
          customer:,
          refund_amount_cents: 0,
          refund_amount_currency: 'CHF',
        )
      end

      xit 'does not create a refund' do
        result = nowpayments_service.create

        aggregate_failures do
          expect(result).to be_success

          expect(result.credit_note).to eq(credit_note)
          expect(result.refund).to be_nil

          expect(modifications_api).not_to have_received(:refund_captured_payment)
        end
      end
    end

    context 'when invoice does not have a payment' do
      let(:payment) { nil }

      xit 'does not create a refund' do
        result = nowpayments_service.create

        aggregate_failures do
          expect(result).to be_success

          expect(result.credit_note).to eq(credit_note)
          expect(result.refund).to be_nil

          expect(modifications_api).not_to have_received(:refund_captured_payment)
        end
      end
    end
  end

  describe '#update_status' do
    let(:refund) do
      create(:refund, credit_note:)
    end

    before { credit_note.pending! }

    it 'updates the refund status' do
      result = nowpayments_service.update_status(
        provider_refund_id: refund.provider_refund_id,
        status: 'succeeded',
      )

      aggregate_failures do
        expect(result).to be_success

        expect(result.refund).to eq(refund)
        expect(result.refund.status).to eq('succeeded')

        expect(result.credit_note).to be_succeeded
      end
    end

    it 'calls SegmentTrackJob' do
      allow(SegmentTrackJob).to receive(:perform_later)

      nowpayments_service.update_status(
        provider_refund_id: refund.provider_refund_id,
        status: 'succeeded',
      )

      expect(SegmentTrackJob).to have_received(:perform_later).with(
        membership_id: CurrentContext.membership,
        event: 'refund_status_changed',
        properties: {
          organization_id: credit_note.organization.id,
          credit_note_id: credit_note.id,
          refund_status: 'succeeded',
        },
      )
    end

    context 'when refund is not found' do
      let(:refund) { nil }

      it 'returns an empty result' do
        result = nowpayments_service.update_status(
          provider_refund_id: 'foo',
          status: 'succeeded',
        )

        aggregate_failures do
          expect(result).to be_success
          expect(result.refund).to be_nil
        end
      end

      context 'with invoice id in metadata' do
        it 'returns an empty result' do
          result = nowpayments_service.update_status(
            provider_refund_id: 'foo',
            status: 'succeeded',
            metadata: { lago_invoice_id: SecureRandom.uuid },
          )

          aggregate_failures do
            expect(result).to be_success
            expect(result.refund).to be_nil
          end
        end

        context 'when invoice belongs to lago' do
          let(:invoice) { create(:invoice) }

          it 'returns a not found failure' do
            result = nowpayments_service.update_status(
              provider_refund_id: 're_123456',
              status: 'succeeded',
              metadata: { lago_invoice_id: invoice.id },
            )

            aggregate_failures do
              expect(result).not_to be_success
              expect(result.error).to be_a(BaseService::NotFoundFailure)
              expect(result.error.message).to eq('nowpayments_refund_not_found')
            end
          end
        end
      end
    end

    context 'when status is not valid' do
      it 'fails' do
        result = nowpayments_service.update_status(
          provider_refund_id: refund.provider_refund_id,
          status: 'invalid',
        )

        aggregate_failures do
          expect(result).not_to be_success

          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:refund_status]).to include('value_is_invalid')
        end
      end
    end

    context 'when status is failed' do
      before { nowpayments_customer }

      xit 'delivers an error webhook' do
        result = nowpayments_service.update_status(
          provider_refund_id: refund.provider_refund_id,
          status: 'failed',
        )

        aggregate_failures do
          expect(result).not_to be_success

          expect(result.error).to be_a(BaseService::ServiceFailure)
          expect(result.error.code).to eq('refund_failed')
          expect(result.error.error_message).to eq('Refund failed to perform')

          expect(SendWebhookJob).to have_been_enqueued
            .with(
              'credit_note.provider_refund_failure',
              credit_note,
              provider_customer_id: nowpayments_customer.provider_customer_id,
              provider_error: {
                message: 'Payment refund failed',
                error_code: nil,
              },
            )
        end
      end
    end
  end
end
