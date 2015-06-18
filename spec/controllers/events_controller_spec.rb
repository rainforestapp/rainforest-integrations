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

  let(:event_name) { 'run_completion' }

  let(:payload) do
    {
      event_name: event_name,
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
      end

      it 'returns a 201' do
        post :create, payload
        expect(response.code).to eq '201'
        expect(json['status']).to eq 'ok'
      end

      it 'delegates to Integrations' do
        expect(::Integrations).to receive(:send_event)
                                   .with(event_name: event_name,
                                         integrations: integrations,
                                         payload: run_payload)
        post :create, payload
      end

      context 'with an unparseable JSON payload' do
        let(:payload) { "I'm{invalid" }

        it 'returns a 400' do
          post :create, payload
          expect(response.code).to eq '400'
        end
      end

      context 'with invalid keys in the JSON request' do
        let(:payload) { { foo: 'bar' }.to_json }

        it 'returns a 400' do
          post :create, payload
          expect(response.code).to eq '400'
        end
      end

      context 'with an unsupported integration' do
        let(:integrations) { [{ key: 'yo', settings: {} }]}

        it 'returns a 400 with a useful error message' do
          post :create, payload
          expect(response.code).to eq '400'
          expect(json['error']).to eq "Integration 'yo' is not supported"
        end
      end

      context 'with a misconfigured integration' do
        let(:integrations) { [{ key: 'slack', settings: {} }]}

        it 'returns a 400 with a useful error message' do
          post :create, payload
          expect(response.code).to eq '400'
          expect(json['error']).to eq "Required setting 'url' was not supplied"
        end
      end

      context 'with a valid event' do
        before do
          allow_any_instance_of(EventValidator).to receive(:validate!)
        end

        it 'returns a 201' do
          post :create, payload
          expect(response.code).to eq '201'
        end
      end

      context 'with an invalid event' do
        before do
          allow_any_instance_of(EventValidator).to receive(:validate!)
                                                    .and_raise EventValidator::InvalidPayloadError
        end

        it 'returns a 400' do
          post :create, payload
          expect(response.code).to eq '400'
        end
      end
    end

    context 'without valid HMAC signature' do
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
  end

  def sign(payload, key)
    digest = OpenSSL::Digest.new('sha256')
    OpenSSL::HMAC.hexdigest(digest, key, payload)
  end

  def json
    JSON.parse(response.body)
  end
end