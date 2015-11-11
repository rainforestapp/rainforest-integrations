require "integrations/base"

module Integrations
  class Slack < Base
    def self.key
      'slack'
    end

    def send_event
      response = HTTParty.post(url,
        :body => {
          :attachments => [{
            :text => message_text,
            :fallback => message_text,
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
      elsif response.code == 404 && response.parsed_response == 'Bad token'
        raise Integrations::UserConfigurationError.new('The provided Slack URL is invalid.')
      elsif response.code != 200
        raise Integrations::MisconfiguredIntegrationError.new('Invalid request to the Slack API.')
      end
    end

    def message_color
      return 'danger' if payload[:run] && payload[:run][:state] == 'failed'

      color_hash = {
        'run_completion' => "good",
        'run_error' => "danger",
        'webhook_timeout' => "danger",
        'run_test_failure' => "danger",
      }

      color_hash[event_type]
    end

    private

    def url
      settings[:url]
    end

    # overwriting generic format for slack hyperlink format
    def run_href
      "<#{payload[:frontend_url]} | Run ##{run[:id]}#{run_description}>"
    end

    def test_href
      failed_test = payload[:failed_test]
      "<#{failed_test[:frontend_url]} | Test ##{failed_test[:id]}: #{failed_test[:title]} (#{payload[:browser]})> "
    end
  end
end
