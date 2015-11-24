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
        frontend_url: "http://www.rainforestqa.com/",
        failed_tests: []
      }
    end
    let(:integrations) { [] }

    subject do
      described_class.send_event(event_type: event_type, integrations: integrations, payload: payload)
    end

    context 'with an invalid integration' do
      let(:integrations) { [{ key: 'yo', settings: [] }] }

      it 'raises an UnsupportedIntegrationError' do
        expect { subject }.to raise_error(Integrations::UnsupportedIntegrationError)
      end
    end

    context 'with a valid integration' do
      let(:integrations) { [{ key: 'slack', settings: [{ foo: 'bar' }] }] }

      it 'calls the corresponding class for the integration' do
        mock_integration = double
        expect(Integrations::Slack).to receive(:new).with(event_type, payload, integrations.first[:settings]).and_return mock_integration
        expect(mock_integration).to receive :send_event
        subject
      end
    end
  end
end
