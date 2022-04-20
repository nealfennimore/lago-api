# frozen_string_literal: true

FactoryBot.define do
  factory :invoice do
    subscription

    from_date { Time.zone.now - 1.month }
    to_date { Time.zone.now - 1.day }
    issuing_date { Time.zone.now - 1.day }
  end
end