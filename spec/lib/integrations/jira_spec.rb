require 'rails_helper'

describe Integrations::Jira do
  subject { described_class.new(event_type, payload, settings) }

  let(:event_type) { 'run_test_failure' }
  let(:access_token) { double('access_token') }
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
      { key: 'oauth_settings', value: { consumer_token: 'foo' } },
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

  before do
    allow_any_instance_of(Integrations::Oauth).to receive(:oauth_access_token).and_return(access_token)
  end

  context "with an unsupported event type" do
    let(:event_type) { 'run_completion' }

    it 'returns without doing anything' do
      expect(access_token).to_not receive(:post)
      expect_any_instance_of(described_class).to_not receive(:create_issue)
      expect_any_instance_of(described_class).to_not receive(:update_issue)
      subject.send_event
    end
  end

  describe '#send_event' do
    let(:send_event) { subject.send_event }
    let(:query_response) { instance_double('query_response', code: 200, body: {issues: issues_queried}.to_json) }
    let(:final_response) { instance_double('query_response', code: 200) }

    before do
      expect(access_token).to receive(:post).with(
        "#{base_url}/rest/api/2/search",
        instance_of(String),
        {'Content-Type' => 'application/json'}
      ).and_return(query_response)
    end

    context 'when there is an authentication error' do
      let(:query_response) { instance_double('query_response', code: 401) }

      it 'raises a Integrations::Error' do
        expect { send_event }.to raise_error(Integrations::Error)
      end
    end

    context 'when there the JIRA base URL is wrong' do
      let(:query_response) { instance_double('query_response', code: 404) }

      it 'raises a Integrations::Error' do
        expect { send_event }.to raise_error(Integrations::Error)
      end
    end

    context 'for any other error' do
      let(:query_response) { instance_double('query_response', code: 500) }

      it 'raises a Integrations::Error' do
        expect { send_event }.to raise_error(Integrations::Error)
      end
    end

    context 'when no matching issues are found' do
      let(:final_response) { instance_double('query_response', code: 201) }

      context 'run_test_failure' do
        it 'posts useful information' do
          allow(access_token).to receive(:post) do |url, post_json, _|
            fields = JSON.parse(post_json)['fields']

            expect(fields['summary']).to eq "Rainforest found a bug in 'Always fails'"
            expect(fields['description']).to eq "Failed test title: Always fails\nhttp://www.rainforestqa.com/"
            expect(fields['environment']).to eq payload[:run][:environment][:name]
          end.and_return(final_response)

          send_event
        end
      end

      context 'webhook_timeout' do
        let(:event_type) { 'webhook_timeout' }

        it 'posts useful information' do
          allow(access_token).to receive(:post) do |url, post_json, _|
            fields = JSON.parse(post_json)['fields']

            expect(fields['summary']).to eq "Your Rainforest webhook has timed out"
            expect(fields['description']).to include payload[:run][:description]
            expect(fields['environment']).to eq payload[:run][:environment][:name]
          end.and_return(final_response)

          send_event
        end
      end
    end

    context "with an existing identical issue" do
      let(:issues_queried) { [{ 'id' => '101' }] }
      let(:final_response) { instance_double('query_response', code: 204) }

      it 'edits the existing issue' do
        expect(access_token).to receive(:put) do |url, put_json, _|
          expect(url).to include('101')
          payload = JSON.parse(put_json).with_indifferent_access

          expect(payload).to include({
            update: { labels: [{ add: 'RepeatedFailures' }] },
            fields: { priority: { name: 'High' } }
          })
        end.and_return(final_response)

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
