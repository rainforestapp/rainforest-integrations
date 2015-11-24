require "integrations/base"

module Integrations
  class Jira < Base
    # NOTE: Jira integration development still underway
    def self.key
      'jira'
    end

    def send_event
      return false unless has_failed_tests?
      if payload[:failed_test]
        return create_issue(payload[:failed_test])
      end

      if payload[:failed_tests]
        payload[:failed_tests].each do |test|
          create_issue(test)
        end
      end
    end

    private

    def create_issue(test)
      response = HTTParty.post(url,
        body: {
          fields: {
            project: { key: settings[:project_key] },
            summary: "Rainforest found a bug in '#{test[:title]}'",
            description: "Failed test name: #{test[:title]}\n#{test[:frontend_url]}",
            issuetype: {
              name: "Bug"
            },
            labels: configured_labels
          }
        }.to_json,
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
        raise Integrations::UserConfigurationError.new('Authentication failed. Wrong username and/or password. Keep in mind that your JIRA username is NOT your email address.')
      when 404
        raise Integrations::UserConfigurationError.new('This JIRA URL does exist.')
      else
        raise Integrations::MisconfiguredIntegrationError.new('Invalid request to the JIRA API.')
      end
    end

    def url
      "#{jira_base_url}/rest/api/2/issue/"
    end

    def jira_base_url
      # MAKE SURE IT DOESN'T HAVE A TRAILING SLASH
      base_url = settings[:jira_base_url]
      base_url.last == "/" ? base_url.chop : base_url
    end

    def has_failed_tests?
      !!(payload[:failed_test] || payload[:failed_tests])
    end

    def configured_labels
      if settings[:labels]
        labels = settings[:labels].to_s.split(',')

        labels.map(&:strip).reject(&:empty?).reject(&:nil?)
      else
        []
      end
    end
  end
end
