# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Types::PaymentProviders::Nowpayments do
  subject { described_class }

  it { is_expected.to have_field(:id).of_type('ID!') }
  it { is_expected.to have_field(:api_key).of_type('String') }
  it { is_expected.to have_field(:code).of_type('String!') }
  it { is_expected.to have_field(:name).of_type('String!') }
  it { is_expected.to have_field(:hmac_key).of_type('String') }
  it { is_expected.to have_field(:success_redirect_url).of_type('String') }
end
