require 'rails_helper'
require 'integrations'

describe Integrations::Jira do
  subject { described_class.new(event_type, payload, settings) }

  let(:event_type) { 'run_test_failure' }
  let(:issue_response) { double('mock response') }
  let(:base_url) { 'http://example.com' }
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
      { key: 'jira_base_url', value: base_url },
      { key: 'project_key', value: 'ABC' }
    ]
  end
  let(:failed_test) do
    {
      id: "20",
      title: "Always fails"
    }
  end
  let(:issues_queried) { [] }
  let(:query_response) { OpenStruct.new({'issues' => issues_queried, :code => 200 }) }

  before do
    allow(issue_response).to receive(:code).and_return(201)
  end

  describe '#send_event' do
    before do
      allow(query_response).to receive(:[]).with('issues').and_return(issues_queried)
      allow(query_response).to receive(:code).and_return(200)
      expect(HTTParty).to receive(:post).with("#{base_url}/rest/api/2/search/", instance_of(Hash))
        .and_return(query_response)
    end

    let(:send_event) { subject.send_event }

    context 'when there is an authentication error' do
      before do
        allow(issue_response).to receive(:code).and_return(401)
      end

      it 'raises a Integrations::Error' do
        expect(HTTParty).to receive(:post).and_return(issue_response)
        expect { send_event }.to raise_error(Integrations::Error)
      end
    end

    context 'when there the JIRA base URL is wrong' do
      before do
        allow(issue_response).to receive(:code).and_return(404)
      end

      it 'raises an error' do
        expect(HTTParty).to receive(:post).and_return(issue_response)
        expect { send_event }.to raise_error(Integrations::Error)
      end
    end

    context 'for any other error' do
      it 'raises an error' do
        allow(issue_response).to receive(:code).and_return(500)
        allow(HTTParty).to receive(:post).and_return(issue_response)
        expect { send_event }.to raise_error(Integrations::Error)
      end
    end

    context 'run_test_failure' do
      it 'has a useful information' do
        allow(HTTParty).to receive(:post) do |url, post_payload|
          fields = JSON.parse(post_payload[:body])['fields']

          expect(fields['summary']).to eq "Rainforest found a bug in 'Always fails'"
          expect(fields['description']).to eq "Failed test name: Always fails\nhttp://www.rainforestqa.com/"
          expect(fields['environment']).to eq payload[:run][:environment][:name]
        end.and_return(issue_response)

        send_event
      end
    end

    context 'webhook_timeout' do
      let(:event_type) { 'webhook_timeout' }

      it 'has a useful information' do
        allow(HTTParty).to receive(:post) do |url, post_payload|
          fields = JSON.parse(post_payload[:body])['fields']

          expect(fields['summary']).to eq "Your Rainforest webhook has timed out"
          expect(fields['description']).to include payload[:run][:description]
          expect(fields['environment']).to eq payload[:run][:environment][:name]
        end.and_return(issue_response)

        send_event
      end
    end

    context "with an existing identical issue" do
      let(:issues_queried) { [{ 'id' => '101' }] }

      it 'edits the existing issue' do
        expect(HTTParty).to receive(:put) do |url, put_payload|
          expect(url).to include('101')
          payload = JSON.parse(put_payload[:body]).with_indifferent_access

          expect(payload).to include({
            update: {
              labels: [{ add: 'RepeatedFailures' }]
            },
            fields: {
              priority: { name: 'High' }
            }
          })
        end.and_return(issue_response)

        send_event
      end
    end
  end

  describe '#jira_base_url' do
    subject { described_class.new(event_type, payload, settings).send(:jira_base_url) }

    before do
      url_setting = settings.find { |s| s[:key] == 'jira_base_url' }
      url_setting[:value] = jira_base_url_setting
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
