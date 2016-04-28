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
        expect(Integrations::Slack).to receive(:new).with(event_type, payload, integrations.first[:settings]).and_return mock_integration
        expect(mock_integration).to receive(:valid?).and_return(false)
        expect(mock_integration).to_not receive :send_event
        subject
      end
    end

    context 'with a valid integration' do
      let(:integrations) { [{ key: 'slack', settings: [{ foo: 'bar' }] }] }

      it 'calls #send_event on the corresponding class for the integration' do
        mock_integration = double
        expect(Integrations::Slack).to receive(:new).with(event_type, payload, integrations.first[:settings]).and_return mock_integration
        expect(mock_integration).to receive(:valid?).and_return(true)
        expect(mock_integration).to receive :send_event
        subject
      end
    end
  end
end
