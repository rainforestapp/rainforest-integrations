class OauthController < ApplicationController
  before_action :oauth_setup

  def request_token
    settings = params[:oauth_settings]

    consumer = OAuth::Consumer.new(
      settings[:consumer_key],
      OpenSSL::PKey::RSA.new(settings[:consumer_secret]),
      {
        site: settings[:site],
        signature_method: settings[:signature_method],
        request_token_path: settings[:request_token_path],
        access_token_path: settings[:access_token_path],
        authorize_path: settings[:authorize_path],
        signature_method: settings[:signature_method]
      }
    )

    request_token = consumer.get_request_token(oauth_callback: oauth_access_token_url)

    session[:oauth][:request_token] = request_token.token
    session[:oauth][:request_token_secret] = request_token.secret
    render json: { authorize_url: request_token.authorize_url }
  end

  def access_token

  end

  private

  def oauth_setup
    session[:oauth] ||= {}
  end
end
