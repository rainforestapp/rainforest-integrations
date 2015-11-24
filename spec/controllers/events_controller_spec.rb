require 'rails_helper'

describe EventsController, type: :controller do
  let(:run_payload) do
    {
      run: {
        id: 3,
        status: 'failed'
      },
      failed_tests: []
    }
  end

  let(:integrations) do
    [
      { key: 'slack', settings: { url: 'https://example.com/fake_url' } }
    ]
  end

  let(:event_type) { 'run_completion' }

  let(:payload) do
    {
      event_type: event_type,
      integrations: integrations,
      payload: run_payload
    }.to_json
  end

  before do
    @request.headers['Accept'] = 'application/json'
    @request.headers['Content-Type'] = 'application/json'
  end

  describe "POST create" do
    let(:key) { "fakefakefake" }
    before do
      stub_const('EventsController::SIGNING_KEY', key)
    end

    context "with a valid HMAC signature" do
      before do
        @request.headers['X-SIGNATURE'] = sign(payload, key)
        allow(Integrations).to receive(:send_event) { 201 }
      end

      it 'returns a 201' do
        post :create, payload
        expect(response.code).to eq '201'
        expect(json['status']).to eq 'ok'
      end

      it 'delegates to Integrations' do
        expect(::Integrations).to receive(:send_event)
                                   .with(event_type: event_type,
                                         integrations: integrations,
                                         payload: run_payload)
        post :create, payload
      end

      context 'with an unparseable JSON payload' do
        before do
          allow(Integrations).to receive(:send_event) { 400 }
        end

        let(:payload) { "I'm{invalid" }

        it 'returns a 400' do
          post :create, payload
          expect(response.code).to eq '400'
        end
      end

      context 'with invalid keys in the JSON request' do
        before do
          allow(Integrations).to receive(:send_event).and_raise PayloadValidator::InvalidPayloadError
        end

        let(:payload) { { foo: 'bar' }.to_json }

        it 'returns a 400' do
          post :create, payload
          expect(response.code).to eq '400'
        end
      end

      context 'with an unsupported integration' do
        before do
          allow(Integrations).to receive(:send_event).and_raise Integrations::UnsupportedIntegrationError.new('yo')
        end

        let(:integrations) { [{ key: 'yo', settings: {} }]}

        it 'returns a 400 with a useful error message' do
          post :create, payload
          expect(response.code).to eq '400'
          expect(json['error']).to eq "Integration 'yo' is not supported"
          expect(json['type']).to eq 'unsupported_integration'
        end
      end

      context 'with a misconfigured integration' do
        before do
          allow(Integrations).to receive(:send_event).and_raise Integrations::MisconfiguredIntegrationError.new('ERROR!')
        end

        it 'returns a 400 with a useful error message' do
          post :create, payload
          expect(response.code).to eq '400'
          expect(json['error']).to eq 'ERROR!'
          expect(json['type']).to eq 'misconfigured_integration'
        end
      end

      context 'with a valid event' do
        before do
          allow_any_instance_of(PayloadValidator).to receive(:validate!)
        end

        it 'returns a 201' do
          post :create, payload
          expect(response.code).to eq '201'
        end
      end

      context 'with an invalid event' do
        before do
          allow(Integrations).to receive(:send_event).and_raise PayloadValidator::InvalidPayloadError
        end

        it 'returns a 400' do
          post :create, payload
          expect(response.code).to eq '400'
        end
      end
    end

    context 'without valid HMAC signature' do
      before do
        allow(Integrations).to receive(:send_event) { 401 }
      end

      it 'returns a 401' do
        post :create, payload
        expect(response.code).to eq '401'
        expect(json['status']).to eq 'unauthorized'
      end
    end

    context 'with invalid HMAC signature' do
      before do
        @request.headers['X-SIGNATURE'] = 'wrong signature'
      end

      it 'returns a 401' do
        post :create, payload
        expect(response.code).to eq '401'
      end
    end

    context 'in development, without a X-SIGNATURE', :vcr do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
        allow(Integrations).to receive(:send_event) { 201 }
      end

      it 'works' do
        post :create, payload
        expect(response.code).to eq '201'
        expect(json['status']).to eq 'ok'
      end
    end
  end

  def sign(payload, key)
    digest = OpenSSL::Digest.new('sha256')
    OpenSSL::HMAC.hexdigest(digest, key, payload)
  end

  def json
    JSON.parse(response.body)
  end
end
