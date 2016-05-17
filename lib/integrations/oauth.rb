# frozen_string_literal: true
module Integrations::Oauth
  REQUIRED_KEYS = %i(signature_method access_token access_secret).freeze

  def oauth_access_token
    @oauth_access_token ||= get_oauth_access_token
  end

  private

  def get_oauth_access_token
    validate_oauth_settings!

    oauth_settings = settings[:oauth_settings].with_indifferent_access
    secrets = oauth_consumer[:secrets].with_indifferent_access

    # NOTE: if we need to use a different encryption algorithm in the future, use
    # the signature method to figure out which to use
    consumer = OAuth::Consumer.new(
      oauth_consumer[:key],
      OpenSSL::PKey::RSA.new(secrets[oauth_settings[:signature_method]]),
      { signature_method: oauth_settings[:signature_method] }
    )
    OAuth::AccessToken.new(
      consumer,
      oauth_settings[:access_token],
      oauth_settings[:access_secret]
    )
  end

  def validate_oauth_settings!
    missing_values = REQUIRED_KEYS - settings[:oauth_settings].keys
    unless missing_values.empty?
      raise Integrations::Error.new('misconfigured_integration', "OAuth settings missing values for: #{missing_values.join(', ')}")
    end
  end
end
