module Integrations
  class PivotalTracker < Base
    # NOTE: Pivotal Tracker integration development still underway

    def message_text
      message = self.send(event_type.dup.concat("_message").to_sym)
      "Your Rainforest Run ##{run[:id]}#{run[:description].present? ? ": #{run[:description]}" : ""} - #{payload[:frontend_url]}) #{message}"
    end

    def run_completion_message
      "is complete!"
    end

    def run_error_message
      "has encountered an error!"
    end

    def webhook_timeout_message
      "has timed out due to a webhook failure!\nIf you need a hand debugging it, please let us know via email at help@rainforestqa.com."
    end

    def run_test_failure_message
      "has a failed a test!"
    end

    def self.key
      'pivotal_tracker'
    end

    def send_event
      # send it to the integration
      response = HTTParty.post(url,
        :body => {
          name: message_text,
          description: event_description,
          story_type: "bug",
          labels: [{ name: "rainforest" }]
        }.to_json,
        :headers => {
          'X-TrackerToken' => settings[:api_token],
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }
      )

      if response.code == 404
        raise Integrations::Error.new('user_configuration_error', 'The project ID provided is was not found.')
      elsif response.code == 403
        raise Integrations::Error.new('user_configuration_error', 'The authorization token is invalid.')
      elsif response.code != 200
        raise Integrations::Error.new('user_configuration_error', 'Invalid request to the Pivotal Tracker API.')
      end
    end

    private

    def url
      "https://www.pivotaltracker.com/services/v5/projects/#{settings[:project_id]}/stories"
    end

    def event_description
      if event_type == "run_completion" && payload[:failed_tests].any?
        txt = "Failed Tests:\n"
        payload[:failed_tests].each { |test| txt += "#{test[:title]}: #{test[:frontend_url]}\n" }
        txt
      end
    end
  end
end
