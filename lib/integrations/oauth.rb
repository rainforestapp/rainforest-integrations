module Integrations::Oauth
  def oauth_access_token
    if @oauth_access_token.nil?
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
end
