require 'spec_helper'
require 'integrations'

describe Integrations::Slack do
  shared_examples_for "Slack notification with a specific text" do |expected_text|
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
        expect(HTTParty).to receive(:post).with(settings[:url], expected_params).and_call_original
        VCR.use_cassette('generic_slack_notification') do
          Integrations::Slack.new(event_name, payload, settings).send_event
        end
    end
  end

  describe '#initialize' do
    let(:event_name) { 'run_failure' }
    let(:payload) do
      {
        run: {
          id: 3,
          status: 'failed'
        }
      }
    end
    let(:settings) { { url: 'https://slack.com/bogus_integration' } }


    subject { described_class.new(event_name, payload, settings) }

    context 'without a valid integration url' do
      let(:settings) { {} }

      it 'raises a MisconfiguredIntegrationError' do
        expect { subject }.to raise_error Integrations::MisconfiguredIntegrationError
      end
    end
  end

  describe "send to Slack" do
    context "notify of run_completion" do
      let(:event_name) { "run_completion" }
      let(:payload) do
        {
          id: 123,
          frontend_url: 'http://example.com',
          run: {
            id: 123,
            status: 'failed',
            time_to_finish: (25.minutes + 3.seconds).to_i
          }
        }
      end
      let(:settings) { {:url => "https://hooks.slack.com/services/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"} }

      it 'sends a message to Slack' do
        VCR.use_cassette('run_completion_notify_slack') do
          Integrations::Slack.new(event_name, payload, settings).send_event
        end
      end

      describe 'run result inclusion in text' do
        it_should_behave_like "Slack notification with a specific text", "Your Rainforest Run <http://example.com|#123> failed. Time to finish: 25 minutes 3 seconds"
      end

      context 'when there is a description' do
        before do
          payload[:run][:description] = 'some description'
        end

        it_should_behave_like "Slack notification with a specific text", "Your Rainforest Run <http://example.com|#123> (some description) failed. Time to finish: 25 minutes 3 seconds"
      end

      describe 'time to finish inclusion in text' do
        context 'when time to finish is under an hour' do
          before do
            payload[:run][:time_to_finish] = (36.minutes + 44.seconds).to_i
          end

          it_should_behave_like "Slack notification with a specific text", "Your Rainforest Run <http://example.com|#123> failed. Time to finish: 36 minutes 44 seconds"
        end

        context 'when time to finish is over an hour' do
          before do
            payload[:run][:time_to_finish] = (6.hours + 36.minutes + 44.seconds).to_i
          end

          it_should_behave_like "Slack notification with a specific text", "Your Rainforest Run <http://example.com|#123> failed. Time to finish: 6 hours 36 minutes 44 seconds"
        end

      end
    end

    context "notify of run_error" do
      let(:event_name) { "run_error" }
      let(:payload) do
        {
          id: 123,
          frontend_url: 'http://example.com',
          run: {
            error_reason: 'We were unable to create social account(s)'
          }
        }
      end
      let(:settings) { {:url => "https://hooks.slack.com/services/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"} }

      it 'sends a message to Slack' do
        VCR.use_cassette('run_error_notify_slack') do
          Integrations::Slack.new(event_name, payload, settings).send_event
        end
      end

      describe 'error reason inclusion' do
        it_should_behave_like "Slack notification with a specific text", "Your Rainforest Run <http://example.com|#123> errored: We were unable to create social account(s)."
      end
    end

    context "notify of run_webhook_timeout" do
      let(:event_name) { "run_webhook_timeout" }
      let(:payload) { {:id => 0} }
      let(:settings) { {:url => "https://hooks.slack.com/services/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"} }

      it 'sends a message to Slack' do
        VCR.use_cassette('run_webhook_timeout_notify_slack') do
          Integrations::Slack.new(event_name, payload, settings).send_event
        end
      end
    end

    context "notify of run_test_failure" do
      let(:event_name) { "run_test_failure" }
      let(:payload) { {:id => 0} }
      let(:settings) { {:url => "https://hooks.slack.com/services/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"} }

      it 'sends a message to Slack' do
        VCR.use_cassette('run_test_failure_notify_slack') do
          Integrations::Slack.new(event_name, payload, settings).send_event
        end
      end
    end

  end

  describe '#message_color' do
    subject { Integrations::Slack.new(event_name, payload, settings).message_color }

    let(:settings) { { url: 'https://slack.com/bogus_integration' } }
    let(:payload) do
      {
        run: {
          id: 3,
          status: 'passed'
        }
      }
    end

    context 'run_completion' do
      let(:event_name) { 'run_completion' }

      context 'when the run is failed' do
        let(:payload) do
          {
            run: {
              id: 3,
              status: 'failed'
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
      let(:event_name) { 'run_error' }

      it { is_expected.to eq 'danger' }
    end

    context 'run_webhook_timeout' do
      let(:event_name) { 'run_webhook_timeout' }

      it { is_expected.to eq 'danger' }
    end

    context 'run_test_failure' do
      let(:event_name) { 'run_test_failure' }

      it { is_expected.to eq 'danger' }
    end
  end
end
