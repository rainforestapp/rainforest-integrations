# frozen_string_literal: true
class Integrations::Jira < Integrations::Base
  include Integrations::Oauth
  SUPPORTED_EVENTS = %w(webhook_timeout run_test_failure).freeze

  def self.key
    'jira'
  end

  def send_event
    unless ok_to_send_event?
      log_info("Unable to create jira issue!")
      return
    end

    create_issue
  end

  private

  def ok_to_send_event?
    SUPPORTED_EVENTS.include?(event_type) &&
    jira_base_url.present? &&
    settings[:project_key].present? &&
    issue_does_not_exist?
  end

  def issue_does_not_exist?
    label = case event_type
            when 'webhook_timeout' then "RfRun#{run[:id]}"
            when 'run_test_failure' then "RfTest#{payload[:failed_test][:id]}"
            end

    body = {
      jql: "status != Done AND project = #{settings[:project_key]} and labels = #{label}",
      maxResults: 1
    }.to_json

    response = oauth_access_token.post("#{jira_base_url}/rest/api/2/search", body, 'Content-Type' => 'application/json')
    response_code = response.code.to_i

    if [401, 404].include?(response_code) || response_code >= 500
      # Either URL, credentials, or something else is wrong, so error out
      validate_response(response)
    elsif response_code >= 300
      # Just create a new issue if you can't search because of some Jira setting.
      log_info("JIRA search failed: #{response.body}. Attempting to post a new issue.")
      return true
    end

    parsed_response = MultiJson.load(response.body, symbolize_keys: true)
    parsed_response[:issues].empty?
  end

  def create_issue
    post_data = case event_type
                when 'webhook_timeout' then create_webhook_timeout_issue
                when 'run_test_failure' then create_test_failure_issue
                end

    response = oauth_access_token.post(
      "#{jira_base_url}/rest/api/2/issue/",
      {fields: post_data}.to_json,
      'Content-Type' => 'application/json'
    )
    validate_response(response)
  end

  def validate_response(response)
    log_error("JIRA API Error: #{response.body}") unless response.code.to_i.between?(200, 299)

    case response.code.to_i
    when 200, 201, 204
      true
    when 401
      raise Integrations::Error.new('user_configuration_error',
                                    "Authentication failed. Wrong username and/or password. \
                                    Keep in mind that your JIRA username is NOT your email address.", response)
    when 404
      raise Integrations::Error.new('user_configuration_error', 'This JIRA URL does exist.', response)
    else
      raise Integrations::Error.new('misconfigured_integration', 'Invalid request to the JIRA API.', response)
    end
  end

  def create_test_failure_issue
    test = payload[:failed_test]
    {
      project: { key: settings[:project_key] },
      labels: ["RfTest#{test[:id]}"],
      issuetype: { name: 'Bug' },
      summary: "Rainforest found a bug in '#{test[:title]}'",
      description: "Failed test title: #{test[:title]}\n#{payload[:frontend_url]}\nEnvironment: #{run[:environment][:name]}\nRun##{run[:id]}"
    }
  end

  def create_webhook_timeout_issue
    run_info = "Run ##{run[:id]}"
    run_info += " (#{run[:description]})" if run[:description].present?
    {
      project: { key: settings[:project_key] },
      labels: ["RfRun#{run[:id]}"],
      issuetype: { name: 'Bug' },
      summary: 'Your Rainforest webhook has timed out',
      description: "Your webhook has timed out for #{run_info} on #{run[:environment][:name]}. \
                    If you need help debugging, please contact us at help@rainforestqa.com"
    }
  end

  def jira_base_url
    # MAKE SURE IT DOESN'T HAVE A TRAILING SLASH
    base_url = settings[:jira_base_url]
    base_url.last == '/' ? base_url.chop : base_url
  end
end
