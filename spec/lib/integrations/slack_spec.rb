require 'rails_helper'
require 'integrations'

describe Integrations::Slack do
  shared_examples_for "Slack notification" do |expected_text|
    it "expects a specific text" do
        expected_params = {:body => {
            :attachments => [{
              :text => expected_text,
              :fallback => expected_text,
              :color => 'danger'
            }]
          }.to_json,
          :headers => {
            'Content-Type' => 'application/json',
            'Accept' => 'application/json'
          }
        }
        response = double('response')
        allow(response).to receive(:code).and_return(200)

        expect(HTTParty).to receive(:post) do |url, options|
          expect(url).to eq settings.first[:value]
          text = JSON.parse(options[:body])['attachments'].first['text']
          expect(text).to eq expected_text
        end.and_return(response)

        described_class.new(event_type, payload, settings).send_event
    end
  end

  describe '#initialize' do
    let(:event_type) { 'run_failure' }
    let(:payload) do
      {
        run: {
          id: 3,
          status: 'failed'
        }
      }
    end


    subject { described_class.new(event_type, payload, settings) }

    context 'without a valid integration url' do
      let(:settings) { [] }

      it 'raises a MisconfiguredIntegrationError' do
        expect { subject }.to raise_error Integrations::Error
      end
    end
  end

  describe "send to Slack" do
    let(:settings) do
      [
        {
          key: 'url',
          value: 'https://hooks.slack.com/services/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'
        }
      ]
    end

    context "notify of run_completion" do
      let(:event_type) { "run_completion" }
      let(:payload) do
        {
          frontend_url: 'http://example.com',
          run: {
            id: 123,
            result: 'failed',
            time_taken: (25.minutes + 3.seconds).to_i,
            total_tests: 10,
            total_passed_tests: 8,
            total_failed_tests: 2,
            total_no_result_tests: 0,
            environment: {
              name: "QA Environment"
            }
          }
        }
      end

      it 'sends a message to Slack' do
        VCR.use_cassette('run_completion_notify_slack') do
          Integrations::Slack.new(event_type, payload, settings).send_event
        end
      end

      describe 'run result inclusion in text' do
        it_should_behave_like "Slack notification", "Your Rainforest Run (<http://example.com | Run #123>) is complete!"
      end

      context 'when there is a description' do
        before do
          payload[:run][:description] = 'some description'
        end

        it_should_behave_like "Slack notification", "Your Rainforest Run (<http://example.com | Run #123: some description>) is complete!"
      end
    end

    context "notify of run_error" do
      let(:event_type) { "run_error" }
      let(:payload) do
        {
          frontend_url: 'http://example.com',
          run: {
            id: 123,
            error_reason: 'We were unable to create social account(s)'
          }
        }
      end

      it 'sends a message to Slack' do
        VCR.use_cassette('run_error_notify_slack') do
          Integrations::Slack.new(event_type, payload, settings).send_event
        end
      end

      describe 'message text' do
        it_should_behave_like "Slack notification", "Your Rainforest Run (<http://example.com | Run #123>) has encountered an error!"
      end
    end

    context "notify of webhook_timeout" do
      let(:event_type) { "webhook_timeout" }
      let(:payload) do
        {
          run: {
            id: 7,
            environment: {
              name: "Foobar"
            }
          },
          frontend_url: 'http://www.example.com'
        }
      end

      it 'sends a message to Slack' do
        VCR.use_cassette('webhook_timeout_notify_slack') do
          Integrations::Slack.new(event_type, payload, settings).send_event
        end
      end

      describe 'message text' do
        it_should_behave_like "Slack notification", "Your Rainforest Run (<http://www.example.com | Run #7>) has timed out due to a webhook failure!\nIf you need a hand debugging it, please let us know via email at help@rainforestqa.com."
      end
    end

    context "notify of run_test_failure" do
      let(:event_type) { "run_test_failure" }
      let(:payload) do
        {
          run: {
            id: 666,
            environment: {
              name: "QA Environment"
            }
          },
          failed_test: {
            id: 7,
            name: "My lucky test"
          },
          frontend_url: 'http://www.example.com',
          browser: {
            full_name: 'Google Chrome'
          }
        }
      end

      it 'sends a message to Slack' do
        VCR.use_cassette('run_test_failure_notify_slack') do
          Integrations::Slack.new(event_type, payload, settings).send_event
        end
      end

      describe "message text" do
        it_should_behave_like "Slack notification", "Your Rainforest Run (<http://www.example.com | Run #666>) has a failed a test!"
      end
    end
  end

  describe '#message_color' do
    # message_color is a private method
    subject { Integrations::Slack.new(event_type, payload, settings).send(:message_color) }

    let(:settings) do
      [
        {
          key: 'url',
          value: 'https://slack.com/bogus_integration'
        }
      ]
    end
    let(:payload) do
      {
        run: {
          id: 3,
          status: 'passed'
        }
      }
    end

    context 'run_completion' do
      let(:event_type) { 'run_completion' }

      context 'when the run is failed' do
        let(:payload) do
          {
            run: {
              id: 3,
              result: 'failed'
            }
          }
        end

        it { is_expected.to eq 'danger' }
      end

      context 'when the run is NOT failed' do
        it { is_expected.to eq 'good' }
      end
    end

    context 'run_error' do
      let(:event_type) { 'run_error' }

      it { is_expected.to eq 'danger' }
    end

    context 'webhook_timeout' do
      let(:event_type) { 'webhook_timeout' }

      it { is_expected.to eq 'danger' }
    end

    context 'run_test_failure' do
      let(:event_type) { 'run_test_failure' }

      it { is_expected.to eq 'danger' }
    end
  end
end
