require 'rails_helper'

RSpec.describe OauthController, type: :controller do
  let(:consumer_secret) { File.read(Rails.root.join('spec', 'support', 'test_private_key')) }
  let(:request_token) { instance_double('request_token', token: 'fake_token', secret: 'fake_sekrit', authorize_url: 'http://example.com') }
  let(:access_token) { instance_double('access_token', token: 'access', secret: 'sekrit') }
  let(:oauth_settings) do
    {
      consumer_key: 'key',
      consumer_secret: consumer_secret,
      signature_method: 'RSA-SHA1',
      request_token_path: 'oauth/request-token',
      access_token_path: 'oauth/access-token',
      authorize_path: 'oauth/authorize'
    }
  end

  before do
    Rails.application.routes.default_url_options[:host] = 'test.host'

    allow_any_instance_of(OAuth::Consumer).to receive(:get_request_token)
      .and_return(request_token)

    allow_any_instance_of(OAuth::RequestToken).to receive(:get_access_token)
      .and_return(access_token)
  end

  describe 'POST request-token' do
    let(:params) do
      {
        instance_id: 121212,
        oauth_settings: oauth_settings
      }
    end

    it 'sets the correct OAuth callback' do
      expect_any_instance_of(OAuth::Consumer).to receive(:get_request_token)
        .with(oauth_callback: "#{oauth_access_token_url}/?instance_id=#{params[:instance_id]}")
        .and_return(request_token)
      post :request_token, params
    end

    it 'stores temporary information in the session' do
      post :request_token, params

      %i(consumer_key signature_method access_token_path).each do |setting|
        expect(session[:oauth][setting.to_s]).to eq(params[:oauth_settings][setting])
      end
    end

    it 'returns the correct authorize url' do
      post :request_token, params
      expect(json['authorize_url']).to eq(request_token.authorize_url)
    end
  end

  describe 'GET access-token' do
    let(:instance_id) { '121212' }
    let(:frontend_url) { 'http://app.rainforest.com' }
    let(:params) { { oauth_verifier: 'foo', instance_id: instance_id } }

    before do
      session[:oauth] = oauth_settings.merge(oauth_token: 'fake_token', oauth_token_secret: 'fake_sekrit')
      allow(request_token).to receive(:get_access_token).and_return(access_token)
    end

    it 'sets the correct values on the request token' do
      expect(OAuth::RequestToken).to receive(:new)
        .with(instance_of(OAuth::Consumer), 'fake_token', 'fake_sekrit')
        .and_return(request_token)
      get :access_token, params: params
    end

    it 'redirects to frontend application with the correct params' do
      get :access_token, params
      expect(response).to redirect_to(/#{ENV['FRONTEND_URL']}/)
      url_params = Rack::Utils.parse_query(URI.parse(response.location).query)
      expect(url_params).to eq({
        'access_token' => access_token.token,
        'access_secret' => access_token.secret,
        'consumer_key' => oauth_settings[:consumer_key],
        'signature_method' => oauth_settings[:signature_method],
        'instance_id' => instance_id,
        'callback_type' => 'oauth_token'
      })
    end
  end
end
