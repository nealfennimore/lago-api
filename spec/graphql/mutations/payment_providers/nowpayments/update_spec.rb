# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::PaymentProviders::Nowpayments::Update, type: :graphql do
  let(:membership) { create(:membership) }
  let(:nowpayments_provider) { create(:nowpayments_provider, organization: membership.organization) }
  let(:success_redirect_url) { Faker::Internet.url }

  let(:mutation) do
    <<-GQL
      mutation($input: UpdateNowpaymentsPaymentProviderInput!) {
        updateNowpaymentsPaymentProvider(input: $input) {
          id,
          successRedirectUrl
        }
      }
    GQL
  end

  before { nowpayments_provider }

  it 'updates an nowpayments provider' do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      query: mutation,
      variables: {
        input: {
          id: nowpayments_provider.id,
          successRedirectUrl: success_redirect_url,
        },
      },
    )

    result_data = result['data']['updateNowpaymentsPaymentProvider']

    expect(result_data['successRedirectUrl']).to eq(success_redirect_url)
  end

  context 'when success redirect url is nil' do
    it 'removes success redirect url from the provider' do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        query: mutation,
        variables: {
          input: {
            id: nowpayments_provider.id,
            successRedirectUrl: nil,
          },
        },
      )

      result_data = result['data']['updateNowpaymentsPaymentProvider']

      expect(result_data['successRedirectUrl']).to eq(nil)
    end
  end

  context 'without current user' do
    it 'returns an error' do
      result = execute_graphql(
        current_organization: membership.organization,
        query: mutation,
        variables: {
          input: {
            id: nowpayments_provider.id,
            successRedirectUrl: success_redirect_url,
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
            id: nowpayments_provider.id,
            successRedirectUrl: success_redirect_url,
          },
        },
      )

      expect_forbidden_error(result)
    end
  end
end
