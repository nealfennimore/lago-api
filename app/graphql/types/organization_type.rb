# frozen_string_literal: true

module Types
  class OrganizationType < SafeOrganizationType
    description 'Organization Type'

    # Some fields (id, name, ...) are defined by the parent type SafeOrganizationType

    field :default_currency, Types::CurrencyEnum, null: false
    field :email, String

    field :legal_name, String
    field :legal_number, String
    field :tax_identification_number, String, null: true

    field :address_line1, String
    field :address_line2, String
    field :city, String
    field :country, Types::CountryCodeEnum, null: true
    field :net_payment_term, Integer, null: false
    field :state, String
    field :zipcode, String

    field :api_key, String, null: false
    field :webhook_url, String

    field :document_number_prefix, String, null: false
    field :document_numbering, Types::Organizations::DocumentNumberingEnum, null: false

    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    field :eu_tax_management, Boolean, null: false

    field :billing_configuration, Types::Organizations::BillingConfiguration, null: true
    field :email_settings, [Types::Organizations::EmailSettingsEnum], null: true
    field :taxes, [Types::Taxes::Object], null: true, resolver: Resolvers::TaxesResolver

    field :adyen_payment_providers, [Types::PaymentProviders::Adyen], null: true
    field :gocardless_payment_providers, [Types::PaymentProviders::Gocardless], null: true
    field :nowpayments_payment_providers, [Types::PaymentProviders::Nowpayments], null: true
    field :stripe_payment_providers, [Types::PaymentProviders::Stripe], null: true

    def billing_configuration
      {
        id: "#{object&.id}-c0nf", # Each nested object needs ID so that appollo cache system can work properly
        vat_rate: object&.vat_rate,
        invoice_footer: object&.invoice_footer,
        invoice_grace_period: object&.invoice_grace_period,
        document_locale: object&.document_locale,
        eu_tax_management: object&.eu_tax_management,
      }
    end

    def webhook_url
      object.webhook_endpoints.map(&:webhook_url).first
    end
  end
end
