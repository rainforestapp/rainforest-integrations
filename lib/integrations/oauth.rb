module Integrations::Oauth
  REQUIRED_KEYS = %i(consumer_key consumer_secret signature_method access_token access_secret).freeze

  def oauth_access_token
    if @oauth_access_token.nil?
      validate_oauth_settings!

      oauth_settings = settings[:oauth_settings].with_indifferent_access
      consumer = OAuth::Consumer.new(
        oauth_settings[:consumer_key],
        OpenSSL::PKey::RSA.new(oauth_settings[:consumer_secret]),
        { signature_method: oauth_settings[:signature_method] }
      )
      @oauth_access_token = OAuth::AccessToken.new(consumer, oauth_settings[:access_token], oauth_settings[:access_secret])
    end
    @oauth_access_token
  end

  private

  def validate_oauth_settings!
    missing_values = REQUIRED_KEYS - settings[:oauth_settings].keys
    unless missing_values.empty?
      raise Integrations::Error.new('misconfigured_integration', "OAuth settings missing values for: #{missing_values.join(', ')}")
    end
  end
end
