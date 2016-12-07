# frozen_string_literal: true
require 'rails_helper'
require 'integrations'

describe Integrations::HipChat do
  shared_examples 'HipChat notification' do |event_type, payload|
    let(:settings) do
      [
        {key: 'room_id', value: 'Test'},
        {key: 'room_token', value: 'sjc91Sq15qhcyciVoDo7f7jFrZhj0OizRKl8D6ED'}
      ]
    end
    let(:oauth_consumer) { '' }

    let(:run_test_failure_payload) do
      {
        run: {
          id: 9382,
          environment: { name: 'QA Environment' },
          frontend_url: 'http://www.example.com',
        },
        failed_test: {
          id: 7,
          title: 'My failing test',
          frontend_url: 'http://www.example.com/foo',
        },
        browser: {
          full_name: 'Google Chrome',
          description: 'Chrome 43'
        }
      }
    end

    let(:run_completion_payload) do
      {
        frontend_url: 'http://www.example.com',
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

    let(:run_error_payload) do
      {
        frontend_url: 'http://www.example.com',
        run: {
          id: 123,
          error_reason: 'We were unable to create social account(s)'
        }
      }
    end

    let(:webhook_timeout_payload) do
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

    let(:integration_test_payload) { {} }

    subject do
      described_class.new(
        event_type,
        self.send(:"#{event_type}_payload"),
        settings,
        oauth_consumer
      )
    end

    it 'sends a notification' do
      VCR.use_cassette("hipchat_notification_#{event_type}") do
        expect(subject.send_event).to be(true)
      end
    end
  end

  describe '#send_event' do
    it_behaves_like 'HipChat notification', 'run_test_failure'
    it_behaves_like 'HipChat notification', 'run_completion'
    it_behaves_like 'HipChat notification', 'run_error'
    it_behaves_like 'HipChat notification', 'webhook_timeout'
    it_behaves_like 'HipChat notification', 'integration_test'
  end
end
