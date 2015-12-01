require 'rails_helper'
require 'integrations'

describe Integrations::Jira do
  subject { described_class.new(event_type, payload, settings) }

  let(:event_type) { 'run_test_failure' }
  let(:mock_response) { double('mock response') }
  let(:payload) do
    {
      run: {
        id: 3,
        status: 'failed',
        description: 'Contains a test that always fails',
        environment: {
          name: 'Testing Env'
        }
      },
      failed_test: failed_test,
      frontend_url: "http://www.rainforestqa.com/"
    }
  end
  let(:settings) do
    [
      { key: 'username', value: 'admin' },
      { key: 'password', value: 'something' },
      { key: 'jira_base_url', value: 'http://example.com' },
      { key: 'project_key', value: 'ABC' }
    ]
  end

  let(:failed_test) do
    {
      id: "20",
      title: "Always fails"
    }
  end

  describe '#send_event' do
    let(:send_event) { subject.send_event }

    context 'when there is an authentication error' do
      before do
        allow(mock_response).to receive(:code).and_return(401)
      end

      it 'raises a Integrations::Error' do
        expect(HTTParty).to receive(:post).and_return(mock_response)
        expect { send_event }.to raise_error(Integrations::Error)
      end
    end

    context 'when there the JIRA base URL is wrong' do
      before do
        allow(mock_response).to receive(:code).and_return(404)
      end

      it 'raises an error' do
        expect(HTTParty).to receive(:post).and_return(mock_response)
        expect { send_event }.to raise_error(Integrations::Error)
      end
    end

    context 'for any other error' do
      it 'raises an error' do
        allow(mock_response).to receive(:code).and_return(500)
        allow(HTTParty).to receive(:post).and_return(mock_response)
        expect { send_event }.to raise_error(Integrations::Error)
      end
    end

    context 'when the event has one or more failed test' do
      context 'run_test_failure' do
        before do
          payload[:failed_test] = failed_test
          allow(mock_response).to receive(:code).and_return(201)
        end

        it 'has a useful information' do
          allow(HTTParty).to receive(:post) do |url, post_payload|
            fields = JSON.parse(post_payload[:body])['fields']

            expect(fields['summary']).to eq "Rainforest found a bug in 'Always fails'"
            expect(fields['description']).to eq "Failed test name: Always fails\nhttp://www.rainforestqa.com/"
            expect(fields['environment']).to eq payload[:run][:environment][:name]
          end.and_return(mock_response)

          send_event
        end
      end

      context 'webhook_timeout' do
        let(:event_type) { 'webhook_timeout' }

        before do
          allow(mock_response).to receive(:code).and_return(201)
        end

        it 'has a useful information' do
          allow(HTTParty).to receive(:post) do |url, post_payload|
            fields = JSON.parse(post_payload[:body])['fields']

            expect(fields['summary']).to eq "Your Rainforest webhook has timed out"
            expect(fields['description']).to include payload[:run][:description]
            expect(fields['environment']).to eq payload[:run][:environment][:name]
          end.and_return(mock_response)

          send_event
        end
      end
    end
  end

  describe '#jira_base_url' do
    subject { described_class.new(event_type, payload, settings).send(:jira_base_url) }

    before do
      settings[2][:value] = jira_base_url_setting
    end

    context 'when URL has a trailing slash' do
      let(:jira_base_url_setting) { 'http://localhost/' }

      it 'removes it' do
        expect(subject).to eq 'http://localhost'
      end
    end

    context 'when URL does NOT have a trailing slash' do
      let(:jira_base_url_setting) { 'http://localhost' }

      it 'does nothing' do
        expect(subject).to eq 'http://localhost'
      end
    end
  end
end
