class Integrations::Jira < Integrations::Base
  include Integrations::Oauth
  SUPPORTED_EVENTS = %(webhook_timeout run_test_failure).freeze

  def self.key
    'jira'
  end

  def send_event
    return unless SUPPORTED_EVENTS.include?(event_type)

    label = case event_type
    when 'webhook_timeout' then "RfRun#{run[:id]}"
    when 'run_test_failure' then "RfTest#{payload[:failed_test][:id]}"
    end

    body = {
      jql: "status != Done AND project = #{settings[:project_key]} and labels = #{label}" ,
      maxResults: 1
    }.to_json

    response = oauth_access_token.post("#{jira_base_url}/rest/api/2/search", body, 'Content-Type' => 'application/json')
    validate_response(response)

    parsed_response = MultiJson.load(response.body, symbolize_keys: true)
    issues = parsed_response[:issues]

    if issues.length > 0
      issue = issues.first
      update_issue(issue[:id])
    else
      create_issue
    end
  end

  private

  def update_issue(issue_id)
    params = {}
    params[:update] = { labels: [{ add: repeated_issue_tag }] } if repeated_issue_tag
    params[:fields] = { priority: { name: repeated_issue_priority } } if repeated_issue_priority

    unless params.empty?
      response = oauth_access_token.put(
        "#{jira_base_url}/rest/api/2/issue/#{issue_id}",
        params.to_json,
        'Content-Type' => 'application/json'
      )

      validate_response(response)
    end
  end

  def create_issue
    post_data = case event_type
    when 'webhook_timeout' then create_webhook_timeout_issue
    when 'run_test_failure' then create_test_failure_issue
    end

    response = oauth_access_token.post(
      "#{jira_base_url}/rest/api/2/issue/",
      post_data.to_json,
      'Content-Type' => 'application/json'
    )
    validate_response(response)
  end

  def validate_response(response)
    case response.code.to_i
    when 200, 201, 204
      true
    when 401
      raise Integrations::Error.new('user_configuration_error', 'Authentication failed. Wrong username and/or password. Keep in mind that your JIRA username is NOT your email address.')
    when 404
      raise Integrations::Error.new('user_configuration_error', 'This JIRA URL does exist.')
    else
      raise Integrations::Error.new('misconfigured_integration', 'Invalid request to the JIRA API.')
    end
  end

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
        labels: ["RfTest#{test[:id]}"],
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
        labels: ["RfRun#{run[:id]}"],
        environment: run[:environment][:name]
      }
    }
  end

  def jira_base_url
    # MAKE SURE IT DOESN'T HAVE A TRAILING SLASH
    base_url = settings[:jira_base_url]
    base_url.last == "/" ? base_url.chop : base_url
  end

  def repeated_issue_tag
    # Hard coded until custom values are in place
    'RepeatedFailures'
  end

  def repeated_issue_priority
    # Hard coded until custom values are in place
    'High'
  end
end
