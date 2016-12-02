# frozen_string_literal: true
require 'rails_helper'
require 'integrations'

describe Integrations::Slack do
  let(:response) { double('response') }

  before do
    allow(response).to receive(:code).and_return(200)
  end

  shared_examples_for 'Slack notification' do |expected_text, expected_color, expected_fallback|
    it 'expects a specific text' do

      expect(HTTParty).to receive(:post) do |url, options|
        expect(url).to eq settings.first[:value]
        text = JSON.parse(options[:body])['attachments'].first['text']
        expect(text).to eq expected_text
      end.and_return(response)

      described_class.new(event_type, payload, settings, oauth_consumer).send_event
    end

    it 'expects a specific color' do
      response = double('response')
      allow(response).to receive(:code).and_return(200)

      expect(HTTParty).to receive(:post) do |url, options|
        expect(url).to eq settings.first[:value]
        color = JSON.parse(options[:body])['attachments'].first['color']
        expect(color).to eq expected_color
      end.and_return(response)

      described_class.new(event_type, payload, settings, oauth_consumer).send_event
    end

    it 'expects a specific fallback text without markdown' do
      response = double('response')
      allow(response).to receive(:code).and_return(200)

      expect(HTTParty).to receive(:post) do |url, options|
        expect(url).to eq settings.first[:value]
        fallback = JSON.parse(options[:body])['attachments'].first['fallback']
        expect(fallback).to eq expected_fallback
      end.and_return(response)

      described_class.new(event_type, payload, settings, oauth_consumer).send_event
    end
  end

  describe 'send to Slack' do
    let(:settings) do
      [
        {
          key: 'url',
          value: 'https://hooks.slack.com/services/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'
        }
      ]
    end
    let(:oauth_consumer) { {} }

    context 'notify of run_completion' do
      let(:expected_text) { 'Your Rainforest Run (Run#123) has failed.' }
      let(:event_type) { 'run_completion' }
      let(:payload) do
        {
          frontend_url: 'http://example.com',
          run: {
            id: 123,
            result: 'passed',
            time_taken: (25.minutes + 3.seconds).to_i,
            total_tests: 10,
            total_passed_tests: 8,
            total_failed_tests: 2,
            total_no_result_tests: 0,
            environment: {
              name: 'QA Environment'
            }
          }
        }
      end

      it 'sends a message to Slack' do
        VCR.use_cassette('run_completion_notify_slack') do
          Integrations::Slack.new(event_type, payload, settings, oauth_consumer).send_event
        end
      end

      describe 'run result inclusion in text' do
        it_should_behave_like 'Slack notification',
                              'Your Rainforest Run (<http://example.com | Run #123>) is complete!',
                              'good',
                              'Your Rainforest Run is complete!'
      end

      context 'when the url is blank' do
        it 'does not send a request to slack' do
          settings[0][:key] = ''
          Integrations::Slack.new(event_type, payload, settings, oauth_consumer).send_event
        end
      end

      context 'when there is a description' do
        before do
          payload[:run][:description] = 'some description'
        end

        it_should_behave_like 'Slack notification',
                              'Your Rainforest Run (<http://example.com | Run #123: some description>) is complete!',
                              'good',
                              'Your Rainforest Run is complete!'
      end

      context 'when the description is an empty string' do
        before do
          payload[:run][:description] = ''
        end

        it_should_behave_like 'Slack notification',
                              'Your Rainforest Run (<http://example.com | Run #123>) is complete!',
                              'good',
                              'Your Rainforest Run is complete!'
      end

      context 'when the run fails' do
        before do
          payload[:run][:result] = 'failed'
        end

        it_should_behave_like 'Slack notification',
                              'Your Rainforest Run (<http://example.com | Run #123>) is complete!',
                              'danger',
                              'Your Rainforest Run is complete!'
      end
    end

    context 'notify of run_error' do
      let(:event_type) { 'run_error' }
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
          Integrations::Slack.new(event_type, payload, settings, oauth_consumer).send_event
        end
      end

      describe 'message text' do
        it_should_behave_like 'Slack notification',
                              'Your Rainforest Run (<http://example.com | Run #123>) has encountered an error!',
                              'danger',
                              'Your Rainforest Run has encountered an error!'
      end
    end

    context 'notify of webhook_timeout' do
      let(:event_type) { 'webhook_timeout' }
      let(:payload) do
        {
          run: {
            id: 7,
            environment: {
              name: 'Foobar'
            }
          },
          frontend_url: 'http://www.example.com'
        }
      end

      it 'sends a message to Slack' do
        VCR.use_cassette('webhook_timeout_notify_slack') do
          Integrations::Slack.new(event_type, payload, settings, oauth_consumer).send_event
        end
      end

      describe 'message text' do
        it_should_behave_like 'Slack notification',
                              "Your Rainforest Run (<http://www.example.com | Run #7>) has timed out due to a webhook failure!\nIf you need a hand debugging it, please let us know via email at help@rainforestqa.com.",
                              'danger',
                              "Your Rainforest Run has timed out due to a webhook failure!\nIf you need a hand debugging it, please let us know via email at help@rainforestqa.com."
      end
    end

    context 'notify of run_test_failure' do
      let(:event_type) { 'run_test_failure' }
      let(:payload) do
        {
          run: {
            id: 666,
            environment: {
              name: 'QA Environment'
            }
          },
          failed_test: {
            id: 7,
            name: 'My lucky test'
          },
          frontend_url: 'http://www.example.com',
          browser: {
            full_name: 'Google Chrome'
          },
          feedback: [
            {
              worker_name: 'Mrs. Awesome',
              note: 'This test is not awesome'
            },
            {
              worker_name: 'Mr. Fail',
              note: 'This test definitely fails'
            }
          ]
        }
      end

      it 'sends a message to Slack' do
        VCR.use_cassette('run_test_failure_notify_slack') do
          Integrations::Slack.new(event_type, payload, settings, oauth_consumer).send_event
        end
      end

      describe 'message text' do
        it_should_behave_like 'Slack notification',
                              'Your Rainforest Run (<http://www.example.com | Run #666>) has a failed test!',
                              'danger',
                              'Your Rainforest Run has a failed test!'
      end

      describe 'feedback' do
        it 'sends tester feedback to slack' do
          expect(HTTParty).to receive(:post) do |_url, options|
            body = MultiJson.load(options[:body], symbolize_keys: true)
            attachment = body[:attachments].first
            expected_feedback = attachment[:fields].last(2)
            expected_feedback.each do |feedback|
              expect(feedback).to include(:title, :value)
              expect(feedback[:short]).to eq(false)
            end
          end.and_return(response)

          VCR.use_cassette('run_test_failure_notify_slack') do
            Integrations::Slack.new(event_type, payload, settings, oauth_consumer).send_event
          end
        end
      end
    end
  end
end
