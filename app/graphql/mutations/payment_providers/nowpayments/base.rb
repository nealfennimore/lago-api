# frozen_string_literal: true

module Mutations
  module PaymentProviders
    module Nowpayments
      class Base < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        def resolve(**args)
          validate_organization!

          result = ::PaymentProviders::NowpaymentsService
            .new(context[:current_user])
            .create_or_update(**args.merge(organization: current_organization))

          result.success? ? result.adyen_provider : result_error(result)
        end
      end
    end
  end
end
