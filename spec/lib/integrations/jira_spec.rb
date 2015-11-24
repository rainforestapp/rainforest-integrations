require 'rails_helper'
require 'integrations'

describe Integrations::Jira do
  subject { described_class.new(event_type, payload, settings) }

  let(:event_type) { 'run_failure' }
  let(:payload) do
    {
      run: {
        id: 3,
        status: 'failed'
      },
      failed_tests: [failed_test]
    }
  end
  let(:settings) do
    [
      {
        key: 'username',
        value: 'admin'
      },
      {
        key: 'password',
        value: 'something'
      },
      {
        key: 'jira_base_url',
        value: 'http://example.com'
      },
      {
        key: 'project_key',
        value: 'ABC'
      }
    ]
  end

  let(:failed_test) do
    {
      id: "20",
      name: "Always fails",
      url: "http://www.rainforestqa.com/"
    }
  end

  describe '#send_event' do
    let(:send_event) { subject.send_event }

    context 'when there is an authentication error' do
      it 'raises a Integrations::UserConfigurationError' do
        settings[2][:value] = 'https://rainforest-integration-testing.atlassian.net'

        VCR.use_cassette('jira/authentication-error') do
          expect { send_event }.to raise_error(Integrations::UserConfigurationError, 'Authentication failed. Wrong username and/or password. Keep in mind that your JIRA username is NOT your email address.')
        end
      end
    end

    context 'when there the JIRA base URL is wrong' do
      it 'raises a Integrations::UserConfigurationError' do
        VCR.use_cassette('jira/wrong-base-url') do
          expect { send_event }.to raise_error(Integrations::UserConfigurationError, 'This JIRA URL does exist.')
        end
      end
    end

    context 'for any other error' do
      it 'raises Integrations::MisconfiguredIntegrationError' do
        mock_response = double('mock response')
        allow(mock_response).to receive(:code).and_return(500)
        allow(HTTParty).to receive(:post).and_return(mock_response)
        expect { send_event }.to raise_error(Integrations::MisconfiguredIntegrationError, 'Invalid request to the JIRA API.')
      end
    end

    context 'when the event has one or more failed test' do
      let(:settings) do
        [
          {
            key: 'username',
            value: 'admin'
          },
          {
            key: 'password',
            value: 'eizEcahrGBQAfT9BBhgoLvYikbpxZZ2LjvJVojevfpRWBBbFgj'
          },
          {
            key: 'jira_base_url',
            value: 'https://rainforest-integration-testing.atlassian.net'
          },
          {
            key: 'project_key',
            value: 'MVBP'
          }
        ]
      end

      let(:payload) do
        {
          run: {
            id: 9,
            status: "failed",
            description: "rainforest run",
            time_taken: 750
          },
          frontend_url: "http://www.rainforestqa.com/"
        }
      end

      context 'when there is no failed tests' do
        it 'does nothing and return false' do
          expect(HTTParty).not_to receive(:post)
          expect(send_event).to eq(false)
        end
      end

      context 'when there are multiple failed tests' do
        before do
          payload[:failed_tests] = [failed_test, failed_test]
        end

        it 'creates on issue per failed test' do
          expect(HTTParty).to receive(:post).twice.and_call_original
          VCR.use_cassette('jira/create-issue-with-three-failed-tests') do
            send_event
          end
        end
      end

      context 'when there is a single failed test' do
        before do
          payload[:failed_test] = failed_test
        end

        it 'creates on issue per failed test' do
          expect(HTTParty).to receive(:post).once.and_call_original
          VCR.use_cassette('jira/create-issue-with-one-failed-test') do
            send_event
          end
        end
      end

      describe 'issue content' do
        before do
          payload[:failed_test] = failed_test
        end

        it 'has a useful summary and description' do
          allow(HTTParty).to receive(:post) do |url, post_payload|
            json_body = JSON.parse(post_payload[:body])

            expect(json_body['fields']['summary']).to eq "Rainforest found a bug in 'Always fails'"
            expect(json_body['fields']['description']).to eq "Failed test name: Always fails\nhttp://www.rainforestqa.com/"
          end.and_call_original

          VCR.use_cassette('jira/create-issue-with-summary-and-description') do
            send_event
          end
        end

        context 'when a label is configured' do
          it 'adds the label to the issue' do
            settings.push( { key: 'labels', value: '    rainforest ' })

            allow(HTTParty).to receive(:post) do |url, post_payload|
              json_body = JSON.parse(post_payload[:body])

              expect(json_body['fields']['labels']).to eq ['rainforest']
            end.and_call_original

            VCR.use_cassette('jira/create-issue-with-one-label') do
              send_event
            end
          end
        end

        context 'when multiple labels are configured' do
          it 'adds the labels to the issue' do
            settings.push({key: 'labels', value: '    rainforest  ,    bug ' })

            allow(HTTParty).to receive(:post) do |url, post_payload|
              json_body = JSON.parse(post_payload[:body])

              expect(json_body['fields']['labels']).to eq ['rainforest', 'bug']
            end.and_call_original

            VCR.use_cassette('jira/create-issue-with-label') do
              send_event
            end
          end
        end

        context 'when there are no label configured' do
          ['    ', nil].each do |empty_configuration|
            it 'does not add a label to the issue' do
              settings.push({ key: 'label', value: empty_configuration })
              allow(HTTParty).to receive(:post) do |url, post_payload|
                json_body = JSON.parse(post_payload[:body])

                expect(json_body['fields']['labels']).to eq []
              end.and_call_original

              VCR.use_cassette('jira/create-issue-with-no-label') do
              send_event
            end
            end
          end
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
