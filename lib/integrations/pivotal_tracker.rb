require "integrations/base"

module Integrations
  class PivotalTracker < Base
    # NOTE: Pivotal Tracker integration development still underway
    include Integrations::MessageFormatter

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
        raise Integrations::UserConfigurationError.new('The project ID provided is was not found.')
      elsif response.code == 403
        raise Integrations::UserConfigurationError.new('The authorization token is invalid.')
      elsif response.code != 200
        raise Integrations::MisconfiguredIntegrationError.new('Invalid request to the Pivotal Tracker API.')
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
