# frozen_string_literal: true

module Mutations
  class RegisterUser < BaseMutation
    argument :email, String, required: true
    argument :password, String, required: true
    argument :organization_name, String, required: true

    type Types::Payloads::RegisterUserType

    def resolve(email:, password:, organization_name:)
      result = UsersService.new.register(
        email,
        password,
        organization_name
      )

      result.success? ? result : execution_error(message: result.error)
    end
  end
end