# frozen_string_literal: true
require 'rails_helper'

describe Integrations do
  describe '.send_event' do
    let(:event_type) { 'run_completion' }
    let(:payload) do
      {
        run: {
          id: 3,
          status: 'failed'
        },
        frontend_url: 'http://www.rainforestqa.com/',
        failed_tests: []
      }
    end
    let(:integrations) { [] }
    let(:oauth_consumer) { {} }

    subject do
      described_class.send_event(
        event_type: event_type,
        integrations: integrations,
        payload: payload,
        oauth_consumer: oauth_consumer
      )
    end

    context 'with a nonexistent integration' do
      let(:integrations) { [{ key: 'yo', settings: [] }] }

      it 'raises an UnsupportedIntegrationError' do
        expect { subject }.to raise_error(Integrations::Error)
      end
    end

    context 'with an integration with invalid settings' do
      let(:integrations) { [{ key: 'slack', settings: [{ foo: 'bar' }] }] }

      it 'does not call #send_event on the corresponding class for the integration' do
        mock_integration = double
        expect(Integrations::Slack).to receive(:new)
          .with(event_type, payload, integrations.first[:settings], oauth_consumer)
          .and_return mock_integration
        expect(mock_integration).to receive(:valid?).and_return(false)
        expect(mock_integration).to_not receive :send_event
        subject
      end
    end

    context 'with a valid integration' do
      let(:integrations) { [{ key: 'slack', settings: [{ foo: 'bar' }] }] }

      it 'calls #send_event on the corresponding class for the integration' do
        mock_integration = double
        expect(Integrations::Slack).to receive(:new)
          .with(event_type, payload, integrations.first[:settings], oauth_consumer)
          .and_return mock_integration
        expect(mock_integration).to receive(:valid?).and_return(true)
        expect(mock_integration).to receive :send_event
        subject
      end
    end

    context 'with an integration_test' do
      let(:event_type) { 'integration_test' }
      let(:payload) do
        {}
      end
      let(:integrations) { [{:key=>'slack', :settings=>{:url=>"https://example.com/fake_url"}}] }
      let(:oauth_consumer) { {} }
      subject do
        described_class.send_event(
          event_type: event_type,
          integrations: integrations,
          payload: payload,
          oauth_consumer: oauth_consumer
        )
      end

      it 'calls #send_event on the corresponding class for the integration' do
        mock_integration = double
        expect(Integrations::Slack).to receive(:new)
          .with(event_type, payload, integrations.first[:settings], oauth_consumer)
          .and_return mock_integration
        expect(mock_integration).to receive(:valid?).and_return(true)
        expect(mock_integration).to receive :send_event
        subject
      end
    end
  end
end
