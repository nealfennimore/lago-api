# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Invoices::Payments::NowpaymentsService, type: :service do
  subject(:nowpayments_service) { described_class.new(invoice) }

  let(:customer) { create(:customer, payment_provider_code: code) }
  let(:organization) { customer.organization }
  let(:nowpayments_payment_provider) { create(:nowpayments_provider, organization:, code:) }
  let(:nowpayments_customer) { create(:nowpayments_customer, customer:) }
  let(:nowpayments_client) { instance_double(Lago::Nowpayments::Client) }
  # let(:payments_api) { Nowpayments::PaymentsApi.new(nowpayments_client, 70) }
  # let(:payment_links_api) { Nowpayments::PaymentLinksApi.new(nowpayments_client, 70) }
  let(:payment_links_response) { generate(:nowpayments_payment_links_response) }
  let(:invoice_response) do
    generate(:nowpayments_invoice_response)
  end
  let(:payments_response) { generate(:nowpayments_payments_response) }
  let(:payment_methods_response) { generate(:nowpayments_payment_methods_response) }
  let(:code) { 'nowpayments_1' }

  let(:invoice) do
    create(
      :invoice,
      organization:,
      customer:,
      total_amount_cents: 1000,
      currency: 'USD',
      ready_for_payment_processing: true,
    )
  end

  describe '#create' do
    before do
      nowpayments_payment_provider
      nowpayments_customer

      stub_request(:post, 'http://example.com/api/v1/example')
        .to_return(invoice_response)

      allow(Lago::Nowpayments::Client).to receive(:new)
        .and_return(nowpayments_client)
      allow(nowpayments_client).to receive(:create_invoice)
        .and_return(invoice_response)
      # allow(checkout).to receive(:payments_api)
      #   .and_return(payments_api)
      # allow(payments_api).to receive(:payments)
      #   .and_return(payments_response)
      # allow(payments_api).to receive(:payment_methods)
      #   .and_return(payment_methods_response)
      allow(Invoices::PrepaidCreditJob).to receive(:perform_later)
    end

    it 'creates an nowpayments payment' do
      result = nowpayments_service.create

      expect(result).to be_success

      aggregate_failures do
        # expect(result.invoice).to be_succeeded
        expect(result.invoice.payment_attempts).to eq(1)
        expect(result.invoice.reload.ready_for_payment_processing).to eq(true)

        expect(result.payment.id).to be_present
        expect(result.payment.invoice).to eq(invoice)
        expect(result.payment.payment_provider).to eq(nowpayments_payment_provider)
        expect(result.payment.payment_provider_customer).to eq(nowpayments_customer)
        expect(result.payment.amount_cents).to eq(invoice.total_amount_cents)
        expect(result.payment.amount_currency).to eq(invoice.currency)
        expect(result.payment.status).to eq('waiting')
      end

      # expect(payments_api).to have_received(:payments)
    end

    context 'generates payment url' do
      it 'generates payment url' do
        expect(nowpayments_service.generate_payment_url.payment_url).to eq("https://sandbox.nowpayments.io/payment/?iid=#{invoice&.id}")
      end
    end

    context 'with no payment provider' do
      let(:nowpayments_payment_provider) { nil }

      it 'does not creates a nowpayments payment' do
        result = nowpayments_service.create

        expect(result).to be_success

        aggregate_failures do
          expect(result.invoice).to eq(invoice)
          expect(result.payment).to be_nil

          # expect(payments_api).not_to have_received(:payments)
        end
      end
    end

    context 'with 0 amount' do
      let(:invoice) do
        create(
          :invoice,
          organization:,
          customer:,
          total_amount_cents: 0,
          currency: 'EUR',
        )
      end

      it 'does not creates a nowpayments payment' do
        result = nowpayments_service.create

        expect(result).to be_success

        aggregate_failures do
          expect(result.invoice).to eq(invoice)
          expect(result.payment).to be_nil

          expect(result.invoice).to be_succeeded

          # expect(payments_api).not_to have_received(:payments)
        end
      end
    end

    context 'when customer does not have a provider customer id' do
      before { nowpayments_customer.update!(provider_customer_id: nil) }

      it 'does create a nowpayments payment' do
        result = nowpayments_service.create

        expect(result).to be_success

        aggregate_failures do
          expect(result.invoice).to eq(invoice)
          # expect(result.payment).to be_nil

          # expect(payments_api).not_to have_received(:payments)
        end
      end
    end

    context 'with error response from nowpayments' do
      let(:payments_error_response) { generate(:nowpayments_payments_error_response) }

      xit 'delivers an error webhook' do
        expect { nowpayments_service.create }.to enqueue_job(SendWebhookJob)
          .with(
            'invoice.payment_failure',
            invoice,
            provider_customer_id: nowpayments_customer.provider_customer_id,
            provider_error: {
              message: 'There are no payment methods available for the given parameters.',
              error_code: 'validation',
            },
          ).on_queue(:webhook)
      end
    end

    context 'with validation error on nowpayments' do
      let(:customer) { create(:customer, organization:, payment_provider_code: code) }

      let(:subscription) do
        create(:subscription, organization:, customer:)
      end

      let(:organization) do
        create(:organization, webhook_url: 'https://webhook.com')
      end

      before do
        subscription
      end

      context 'when changing payment method fails with invalid card' do
        xit 'delivers an error webhook' do
          expect { nowpayments_service.create }.to enqueue_job(SendWebhookJob)
            .with(
              'invoice.payment_failure',
              invoice,
              provider_customer_id: nowpayments_customer.provider_customer_id,
              provider_error: {
                message: 'Invalid card number',
                error_code: nil,
              },
            ).on_queue(:webhook)
        end
      end

      context 'when payment fails with invalid card' do
        xit 'delivers an error webhook' do
          expect { nowpayments_service.create }.to enqueue_job(SendWebhookJob)
            .with(
              'invoice.payment_failure',
              invoice,
              provider_customer_id: nowpayments_customer.provider_customer_id,
              provider_error: {
                message: 'Invalid card number',
                error_code: nil,
              },
            ).on_queue(:webhook)
        end
      end
    end

    context 'with error on nowpayments' do
      let(:customer) { create(:customer, organization:, payment_provider_code: code) }

      let(:subscription) do
        create(:subscription, organization:, customer:)
      end

      let(:organization) do
        create(:organization, webhook_url: 'https://webhook.com')
      end

      before do
        subscription

        allow(payments_api).to receive(:payments)
          .and_raise(Lago::Nowpayments::NowpaymentsError.new(nil, nil, 'error', 'code'))
      end

      xit 'delivers an error webhook' do
        expect { nowpayments_service.__send__(:create_nowpayments_payment) }
          .to raise_error(Lago::Nowpayments::NowpaymentsError)

        expect(SendWebhookJob).to have_been_enqueued
          .with(
            'invoice.payment_failure',
            invoice,
            provider_customer_id: nowpayments_customer.provider_customer_id,
            provider_error: {
              message: 'error',
              error_code: 'code',
            },
          )
      end
    end
  end

  # describe '#payment_method_params' do
  #   subject(:payment_method_params) { nowpayments_service.__send__(:payment_method_params) }

  #   let(:params) do
  #     {
  #       merchantAccount: nowpayments_payment_provider.merchant_account,
  #       shopperReference: nowpayments_customer.provider_customer_id,
  #     }
  #   end

  #   before do
  #     nowpayments_payment_provider
  #     nowpayments_customer
  #   end

  #   it 'returns payment method params' do
  #     expect(payment_method_params).to eq(params)
  #   end
  # end

  describe '.update_payment_status' do
    let(:payment) do
      create(
        :payment,
        invoice:,
        provider_payment_id: 'ch_123456',
        status: 'Pending',
      )
    end

    before do
      allow(SendWebhookJob).to receive(:perform_later)
      payment
    end

    xit 'updates the payment and invoice payment_status' do
      result = nowpayments_service.update_payment_status(
        provider_payment_id: 'ch_123456',
        status: 'Authorised',
      )

      expect(result).to be_success
      expect(result.payment.status).to eq('Authorised')
      expect(result.invoice.reload).to have_attributes(
        payment_status: 'succeeded',
        ready_for_payment_processing: false,
      )
    end

    context 'when status is failed' do
      xit 'updates the payment and invoice status' do
        result = nowpayments_service.update_payment_status(
          provider_payment_id: 'ch_123456',
          status: 'Refused',
        )

        expect(result).to be_success
        expect(result.payment.status).to eq('Refused')
        expect(result.invoice.reload).to have_attributes(
          payment_status: 'failed',
          ready_for_payment_processing: true,
        )
      end
    end

    context 'when invoice is already succeeded' do
      before { invoice.succeeded! }

      it 'does not update the status of invoice and payment' do
        result = nowpayments_service.update_payment_status(
          provider_payment_id: 'ch_123456',
          status: %w[Authorised SentForSettle SettleScheduled Settled Refunded].sample,
        )

        expect(result).to be_success
        expect(result.invoice.payment_status).to eq('succeeded')
      end
    end

    context 'with invalid status' do
      it 'does not update the payment_status of invoice' do
        result = nowpayments_service.update_payment_status(
          provider_payment_id: 'ch_123456',
          status: 'foo-bar',
        )

        aggregate_failures do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages.keys).to include(:payment_status)
          expect(result.error.messages[:payment_status]).to include('value_is_invalid')
        end
      end
    end

    context 'when payment is not found and it is one time payment' do
      let(:payment) { nil }

      before do
        nowpayments_payment_provider
        nowpayments_customer
      end

      it 'creates a payment and updates invoice payment status' do
        result = nowpayments_service.update_payment_status(
          provider_payment_id: 'ch_123456',
          status: 'succeeded',
          metadata: { lago_invoice_id: invoice.id, payment_type: 'one-time' },
        )

        aggregate_failures do
          expect(result).to be_success
          expect(result.payment.status).to eq('succeeded')
          expect(result.invoice.reload).to have_attributes(
            payment_status: 'succeeded',
            ready_for_payment_processing: false,
          )
        end
      end
    end
  end

  describe '#generate_payment_url' do
    before do
      nowpayments_payment_provider
      nowpayments_customer

      allow(Lago::Nowpayments::Client).to receive(:new)
        .and_return(nowpayments_client)
      # allow(nowpayments_client).to receive(:checkout)
      #   .and_return(checkout)
      # allow(checkout).to receive(:payment_links_api)
      # .and_return(payment_links_api)
      # allow(payment_links_api).to receive(:payment_links)
      #   .and_return(payment_links_response)
    end

    it 'generates payment url' do
      nowpayments_service.generate_payment_url

      # expect(payment_links_api).to have_received(:payment_links)
    end

    context 'when invoice is succeeded' do
      before { invoice.succeeded! }

      it 'does not generate payment url' do
        nowpayments_service.generate_payment_url

        # expect(payment_links_api).not_to have_received(:payment_links)
      end
    end

    context 'when invoice is voided' do
      before { invoice.voided! }

      it 'does not generate payment url' do
        nowpayments_service.generate_payment_url

        # expect(payment_links_api).not_to have_received(:payment_links)
      end
    end
  end
end
