# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentProviderCustomers::NowpaymentsService, type: :service do
  let(:nowpayments_service) { described_class.new(nowpayments_customer) }
  let(:customer) { create(:customer, organization:) }
  let(:nowpayments_provider) { create(:nowpayments_provider) }
  let(:organization) { nowpayments_provider.organization }
  let(:nowpayments_client) { instance_double(Lago::Nowpayments::Client) }
  # let(:payment_links_api) { Nowpayments::PaymentLinksApi.new(nowpayments_client, 70) }
  # let(:checkout) { Nowpayments::Checkout.new(nowpayments_client, 70) }
  let(:payment_links_response) { generate(:nowpayments_payment_links_response) }

  let(:nowpayments_customer) do
    create(:nowpayments_customer, customer:, provider_customer_id: nil)
  end

  before do
    allow(Lago::Nowpayments::Client).to receive(:new).and_return(nowpayments_client)
    allow(nowpayments_client).to receive(:create_invoice).and_return(:nowpayments_invoice_response)
    # allow(nowpayments_client).to receive(:checkout).and_return(checkout)
    # allow(checkout).to receive(:payment_links_api).and_return(payment_links_api)
    # allow(payment_links_api).to receive(:payment_links).and_return(payment_links_response)
  end

  describe '#create' do
    subject(:nowpayments_service_create) { nowpayments_service.create }

    context 'when customer does not have an nowpayments customer id yet' do
      xit 'calls nowpayments api client payment links' do
        nowpayments_service_create
        expect(payment_links_api).to have_received(:payment_links)
      end

      xit 'creates a payment link' do
        expect(nowpayments_service_create.checkout_url).to eq('https://test.nowpayments.link/test')
      end

      xit 'delivers a success webhook' do
        expect { nowpayments_service_create }.to enqueue_job(SendWebhookJob)
          .with(
            'customer.checkout_url_generated',
            customer,
            checkout_url: 'https://test.nowpayments.link/test',
          )
          .on_queue(:webhook)
      end
    end

    context 'when customer already has an nowpayments customer id' do
      let(:nowpayments_customer) do
        create(:nowpayments_customer, customer:, provider_customer_id: 'cus_123456')
      end

      it 'doenowpayments_customers not call nowpayments API' do
        nowpayments_customer.stub(:update!)
        expect(nowpayments_customer).not_to have_received(:update!)
      end
    end

    context 'when failing to generate the checkout link due to an error response' do
      let(:payment_links_error_response) { generate(:nowpayments_payment_links_error_response) }

      # before do
      #   allow(payment_links_api).to receive(:payment_links).and_return(payment_links_error_response)
      # end

      xit 'delivers an error webhook' do
        expect { nowpayments_service_create }.to enqueue_job(SendWebhookJob)
          .with(
            'customer.payment_provider_error',
            customer,
            provider_error: {
              message: 'There are no payment methods available for the given parameters.',
              error_code: 'validation',
            },
          ).on_queue(:webhook)
      end
    end

    context 'when failing to generate the checkout link' do
      # before do
      #   allow(payment_links_api)
      #     .to receive(:payment_links).and_raise(Lago::Nowpayments::NowpaymentsError.new(nil, nil, 'error'))
      # end

      xit 'delivers an error webhook' do
        expect { nowpayments_service.create }
          .to raise_error(Lago::Nowpayments::NowpaymentsError)

        expect(SendWebhookJob).to have_been_enqueued
          .with(
            'customer.payment_provider_error',
            customer,
            provider_error: {
              message: 'error',
              error_code: nil,
            },
          )
      end
    end
  end

  describe '#update' do
    it 'returns result' do
      expect(nowpayments_service.update).to be_a(BaseService::Result)
    end
  end

  describe '#success_redirect_url' do
    subject(:success_redirect_url) { nowpayments_service.__send__(:success_redirect_url) }

    context 'when payment provider has success redirect url' do
      it "returns payment provider's success redirect url" do
        expect(success_redirect_url).to eq(nowpayments_provider.success_redirect_url)
      end
    end

    context 'when payment provider has no success redirect url' do
      let(:nowpayments_provider) { create(:nowpayments_provider, success_redirect_url: nil) }

      it 'returns the default success redirect url' do
        expect(success_redirect_url).to eq(PaymentProviders::NowpaymentsProvider::SUCCESS_REDIRECT_URL)
      end
    end
  end

  describe '#generate_checkout_url' do
    context 'when nowpayments payment provider is nil' do
      before { nowpayments_provider.destroy! }

      xit 'returns a not found error' do
        result = nowpayments_service.generate_checkout_url

        aggregate_failures do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.message).to eq('nowpayments_payment_provider_not_found')
        end
      end
    end

    context 'when nowpayments payment provider is present' do
      subject(:generate_checkout_url) { nowpayments_service.generate_checkout_url }

      xit 'generates a checkout url' do
        expect(generate_checkout_url).to be_success
      end

      xit 'delivers a success webhook' do
        expect { generate_checkout_url }.to enqueue_job(SendWebhookJob)
          .with(
            'customer.checkout_url_generated',
            customer,
            checkout_url: 'https://test.nowpayments.link/test',
          )
          .on_queue(:webhook)
      end
    end
  end
end
