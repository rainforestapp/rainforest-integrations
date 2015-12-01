module Integrations
  class Jira < Base
    SUPPORTED_EVENTS = %(webhook_timeout run_test_failure).freeze

    def self.key
      'jira'
    end

    def send_event
      return unless SUPPORTED_EVENTS.include?(event_type)

      post_data = case event_type
      when 'webhook_timeout' then create_webhook_timeout_issue
      when 'run_test_failure' then create_test_failure_issue
      end

      response = HTTParty.post("#{jira_base_url}/rest/api/2/issue/",
        body: post_data.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        },
        basic_auth: {
          username: settings[:username],
          password: settings[:password]
        }
      )

      case response.code
      when 201
        # yay, that worked!
        true
      when 401
        raise Integrations::Error.new('user_configuration_error', 'Authentication failed. Wrong username and/or password. Keep in mind that your JIRA username is NOT your email address.')
      when 404
        raise Integrations::Error.new('user_configuration_error', 'This JIRA URL does exist.')
      else
        raise Integrations::Error.new('misconfigured_integration', 'Invalid request to the JIRA API.')
      end
    end

    private

    def create_test_failure_issue
      test = payload[:failed_test]
      {
        fields: {
          project: { key: settings[:project_key] },
          summary: "Rainforest found a bug in '#{test[:title]}'",
          description: "Failed test name: #{test[:title]}\n#{payload[:frontend_url]}",
          issuetype: {
            name: "Bug"
          },
          environment: run[:environment][:name]
        }
      }
    end

    def create_webhook_timeout_issue
      {
        fields: {
          project: { key: settings[:project_key] },
          summary: "Your Rainforest webhook has timed out",
          description: "Your webhook has timed out for you run (#{run[:description]}). If you need help debugging, please contact us at help@rainforestqa.com",
          issuetype: {
            name: "Bug"
          },
          environment: run[:environment][:name]
        }
      }
    end

    def jira_base_url
      # MAKE SURE IT DOESN'T HAVE A TRAILING SLASH
      base_url = settings[:jira_base_url]
      base_url.last == "/" ? base_url.chop : base_url
    end
  end
end
