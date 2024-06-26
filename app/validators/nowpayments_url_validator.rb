# frozen_string_literal: true

class NowpaymentsUrlValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    record.errors.add(attribute, :url_invalid) unless url_valid?(value)
  end

  private

  def url_valid?(url)
    url =~ %r{.+://.+}
  end
end
