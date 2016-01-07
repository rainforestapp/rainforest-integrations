class OauthController < ApplicationController
  FRONTEND_URL = ENV['FRONTEND_URL'].freeze
  skip_after_action :cors_set_access_control_headers, only: :access_token

  def request_token
    settings = params[:oauth_settings]
    consumer = create_consumer(settings)

    request_token = consumer.get_request_token(oauth_callback: "#{oauth_access_token_url}/?instance_id=#{params[:instance_id]}")

    session[:oauth] = settings.to_hash
    session[:oauth][:oauth_token] = request_token.token
    session[:oauth][:oauth_token_secret] = request_token.secret

    render json: { authorize_url: request_token.authorize_url }
  end

  def access_token
    settings = session[:oauth].to_hash.with_indifferent_access
    session[:oauth] = nil

    consumer = create_consumer(settings)
    request_token = OAuth::RequestToken.new(consumer, settings[:oauth_token], settings[:oauth_token_secret])
    access_token = request_token.get_access_token(oauth_verifier: params[:oauth_verifier])

    returned_params = {
      access_token: access_token.token,
      access_secret: access_token.secret,
      consumer_key: settings[:consumer_key],
      signature_method: settings[:signature_method],
      instance_id: params[:instance_id],
      callback_type: 'oauth_token'
    }

    # Return the authentication information needed for future OAuth Access
    redirect_to "#{FRONTEND_URL}/settings/integrations?#{returned_params.to_query}"
  end

  private

  def create_consumer(settings)
    OAuth::Consumer.new(
      settings[:consumer_key],
      OpenSSL::PKey::RSA.new(settings[:consumer_secret]),
      {
        site: settings[:site],
        signature_method: settings[:signature_method],
        request_token_path: settings[:request_token_path],
        access_token_path: settings[:access_token_path],
        authorize_path: settings[:authorize_path]
      }
    )
  end
end
