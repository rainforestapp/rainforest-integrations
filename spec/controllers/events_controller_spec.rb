# frozen_string_literal: true
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
  let(:oauth_consumer) { {} }

  let(:payload) do
    {
      event_type: event_type,
      integrations: integrations,
      payload: run_payload,
      oauth_consumer: oauth_consumer
    }.to_json
  end

  before do
    @request.headers['Accept'] = 'application/json'
    @request.headers['Content-Type'] = 'application/json'
  end

  describe 'POST create' do
    let(:key) { 'fakefakefake' }
    before do
      stub_const('EventsController::SIGNING_KEY', key)
    end

    context 'with a valid HMAC signature' do
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
          .with(
            event_type: event_type,
            integrations: integrations,
            payload: run_payload,
            oauth_consumer: oauth_consumer
          )
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
        let(:service_response) { double(:service_response, code: 400, body: "errors") }

        before do
          allow(Integrations).to receive(:send_event).and_raise Integrations::Error.new('unsupported_integration', "Integration 'yo' is not supported", service_response)
        end

        let(:integrations) { [{ key: 'yo', settings: [] }]}

        it 'returns a 400 with a useful error message' do
          post :create, payload
          expect(response.code).to eq '400'
          expect(json['error']).to eq "Integration 'yo' is not supported"
          expect(json['type']).to eq 'unsupported_integration'
          expect(json['failed_response_body']).to eq service_response.body
          expect(json['failed_response_code']).to eq service_response.code
        end
      end

      context 'with a misconfigured integration' do
        let(:service_response) { double(:response, body: "{\"errorMessages\": [\"SomeField is required\"], \"errors\": {}}", code: '400')}

        before do
          allow(Integrations).to receive(:send_event).and_raise Integrations::Error.new('misconfigured_integration', 'ERROR!', service_response)
        end

        it 'returns a 400 with a useful error message' do
          post :create, payload
          expect(response.code).to eq '400'
          expect(json['error']).to eq 'ERROR!'
          expect(json['type']).to eq 'misconfigured_integration'
          expect(json['failed_response_body']).to be_present
          expect(json['failed_response_code']).to eq '400'
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
end
