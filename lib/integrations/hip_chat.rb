module Integrations
  class HipChat < Base
    # NOTE: HipChat integration development still underway
    include Integrations::MessageFormatter

    def self.key
      "hip_chat"
    end

    def send_event
      response = HTTParty.post(url,
        body: {
          from: "Rainforest QA",
          color: message_color,
          message: message_text,
          notify: true,
          message_format: 'html'
        }.to_json,
        headers: {
          "Authorization" => "Bearer #{settings[:room_token]}",
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }
      )

      # HipChat returns nil for successful notifications for some reason
      if response.nil?
        true
      elsif response.code == 404
        raise Integrations::Error.new('user_configuration_error', 'The room provided is was not found.')
      elsif response.code == 401
        raise Integrations::Error.new('user_configuration_error', 'The authorization token is invalid.')
      elsif response.code != 200
        raise Integrations::Error.new('misconfigured_integration', 'Invalid request to the HipChat API.')
      end
    end

    private

    def url
      "https://api.hipchat.com/v2/room/#{settings[:room_id]}/notification"
    end

    def message_color
      return 'red' if payload[:run] && payload[:run][:state] == 'failed'

      color_hash = {
        'run_completion' => "green",
        'run_error' => "yellow",
        'webhook_timeout' => "yellow",
        'run_test_failure' => "red",
      }

      color_hash[event_type]
    end

    def run_href
      "<a href=\"#{payload[:frontend_url]}\">Run ##{run[:id]}#{run_description}</a>"
    end

    def test_href
      failed_test = payload[:failed_test]
      "<a href=\"#{failed_test[:frontend_url]}\">Test ##{failed_test[:id]}: #{failed_test[:title]}</a> (#{payload[:browser]})"
    end
  end
end
