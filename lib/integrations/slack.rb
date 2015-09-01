require "integrations/base"

module Integrations
  class Slack < Base
    def self.key
      'slack'
    end

    def send_event
      # send it to the integration
      response = HTTParty.post(url,
        :body => {
          :attachments => [{
            :text => message_text[event_name],
            :fallback => message_text[event_name],
            :color => message_color
          }]
        }.to_json,
        :headers => {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }
      )
      if response.code == 500 && response.parsed_response == 'no_text'
        raise Integrations::MisconfiguredIntegrationError.new('Invalid request to the Slack API (maybe the JSON structure is wrong?).')
      elseif response.code == 404 && response.parsed_response == 'Bad token'
        raise Integrations::UserConfigurationError.new('The provided Slack URL is invalid.')
      elseif response.code != 200
        raise Integrations::MisconfiguredIntegrationError.new('Invalid request to the Slack API.')
      end
    end

    def message_color
      return 'danger' if payload[:run] && payload[:run][:status] == 'failed'

      color_hash = {
        'run_completion' => "good",
        'run_error' => "danger",
        'run_webhook_timeout' => "danger",
        'run_test_failure' => "danger",
      }

      color_hash[event_name]
    end

    private

    def message_text
      description = run[:description].nil? ? '' : ("(#{run[:description]})" + ' ')
      {
        'run_completion' => "Your Rainforest Run <#{payload[:frontend_url]}|##{payload[:id]}> #{description}#{run[:status]}.",
        'run_error' => "Your Rainforest Run <#{payload[:frontend_url]}|##{payload[:id]}> #{description}errored: #{run[:error_reason]}.",
        'run_webhook_timeout' => "Your Rainforest run <#{payload[:frontend_url]}|##{payload[:id]}> #{description}timed out due to your webhook failing. If you need a hand debugging it, please let us know via email at team@rainforestqa.com.",
        'run_test_failure' => "<#{payload[:frontend_url]}|Test ##{payload[:id]}> failed!"
      }
    end

    def url
      settings[:url]
    end
  end
end
