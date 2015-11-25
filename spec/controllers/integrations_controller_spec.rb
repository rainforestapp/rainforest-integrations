require 'rails_helper'

describe IntegrationsController, type: :controller do
  before do
    @request.headers['Accept'] = 'application/json'
    @request.headers['Content-Type'] = 'application/json'
  end

  describe 'GET show' do
    let(:key) { 'slack' }

    before do
      get :show, { 'id' => key }
    end

    context 'with a valid key' do
      it 'returns a 200' do
        expect(response.code).to eq '200'
      end

      it 'returns the schema for the integration' do
        body = JSON.parse(response.body)

        expect(body['title']).to eq 'Slack'
        expect(body['key']).to eq 'slack'
        expect(body).to have_key 'settings'
      end
    end

    context "with a key that doesn't exist" do
      let(:key) { 'norton' }

      it 'returns a 404' do
        expect(response.code).to eq '404'
      end
    end
  end

  describe 'GET index' do
    before do
      get :index
    end

    it 'returns a 200' do
      expect(response.code).to eq '200'
    end

    it 'returns a list of schemas for all supported integrations' do
      body = JSON.parse(response.body)
      expect(body).to be_a Hash
      expect(body['integrations'].count).to eq Integration.public_integrations.count
      expect(body['event_types'].count). to eq Integration.supported_event_types.count
    end
  end
end
