# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::PaymentProviders::Nowpayments::Create, type: :graphql do
  let(:membership) { create(:membership) }
  let(:api_key) { 'api_key_123456_abc' }
  let(:hmac_key) { 'hmac_124' }
  let(:code) { 'nowpayments_1' }
  let(:name) { 'Nowpayments 1' }
  let(:success_redirect_url) { Faker::Internet.url }

  let(:mutation) do
    <<-GQL
      mutation($input: AddNowpaymentsPaymentProviderInput!) {
        addNowpaymentsPaymentProvider(input: $input) {
          id,
          apiKey,
          code,
          name,
          hmacKey,
          successRedirectUrl
        }
      }
    GQL
  end

  it 'creates an nowpayments provider' do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      query: mutation,
      variables: {
        input: {
          apiKey: api_key,
          hmacKey: hmac_key,
          code:,
          name:,
          successRedirectUrl: success_redirect_url,
        },
      },
    )

    result_data = result['data']['addNowpaymentsPaymentProvider']

    aggregate_failures do
      expect(result_data['id']).to be_present
      expect(result_data['apiKey']).to eq('••••••••…abc')
      expect(result_data['hmacKey']).to eq('••••••••…124')
      expect(result_data['code']).to eq(code)
      expect(result_data['name']).to eq(name)
      expect(result_data['successRedirectUrl']).to eq(success_redirect_url)
    end
  end

  context 'without current user' do
    it 'returns an error' do
      result = execute_graphql(
        current_organization: membership.organization,
        query: mutation,
        variables: {
          input: {
            apiKey: api_key,
            code:,
            name:,
          },
        },
      )

      expect_unauthorized_error(result)
    end
  end

  context 'without current organization' do
    it 'returns an error' do
      result = execute_graphql(
        current_user: membership.user,
        query: mutation,
        variables: {
          input: {
            apiKey: api_key,
            code:,
            name:,
          },
        },
      )

      expect_forbidden_error(result)
    end
  end
end
