require "integrations/base"

class Integrations::Slack < Integrations::Base
  SUPPORTED_EVENTS = %w(run_completion run_error webhook_timeout run_test_failure).freeze

  include Integrations::MessageFormatter

  def self.key
    'slack'
  end

  def send_event
    return unless SUPPORTED_EVENTS.include?(event_type)
    response = HTTParty.post(settings[:url],
      :body => {
        :attachments => attachments
      }.to_json,
      :headers => {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      }
    )

    if response.code == 500 && response.parsed_response == 'no_text'
      raise Integrations::Error.new('user_configuration_error', 'Invalid request to the Slack API (maybe the JSON structure is wrong?).')
    elsif response.code == 404 && response.parsed_response == 'Bad token'
      raise Integrations::Error.new('user_configuration_error', 'The provided Slack URL is invalid.')
    elsif response.code != 200
      raise Integrations::Error.new('misconfigured_integration', 'Invalid request to the Slack API.')
    end
  end

  private

  def attachments
    attachment = {
      text: message_text,
      color: message_color
    }

    case event_type
    when 'run_completion'
      attachment[:fields] = run_completion_fields
    when 'run_error'
      attachment[:fields] = run_error_fields
    when 'run_test_failure'
      attachment[:fields] = run_test_failure_fields
    end

    return [attachment]
  end

  # The order here intentionally 'alternates' between run info and tests info because
  # it's laid out better in slack's table-format that way
  def run_completion_fields
    [
      { title: "Result", value: run[:result].capitalize, short: true },
      {
        title: "Tests Passed: #{run[:total_passed_tests]} - #{test_percentage(run[:total_passed_tests])}%",
        value: "<#{payload[:frontend_url]}?expandedGroups%5B%5D=passed | View all Passed tests>",
        short: true
      },
      { title: "Duration", value: humanize_secs(run[:time_taken]), short: true },
      {
        title: "Tests Failed: #{run[:total_failed_tests]} - #{test_percentage(run[:total_failed_tests])}%",
        value: "<#{payload[:frontend_url]}?expandedGroups%5B%5D=failed | View all Failed tests>",
        short: true
      },
      { title: "Environment", value: run[:environment][:name], short: true },
      {
        title: "Other Results: #{run[:total_no_result_tests]} - #{test_percentage(run[:total_no_result_tests])}%",
        value: "<#{payload[:frontend_url]}?expandedGroups%5B%5D=no_result | View all tests with no result>",
        short: true
      }
    ]
  end

  def run_error_fields
    if run[:error_reason].nil? || run[:error_reason].empty?
      run[:error_reason] = "Error reason was unspecified (please contact help@rainforestqa.com if you'd like help debugging this)"
    end
    [{ title: "Error Reason", value: run[:error_reason], short: false }]
  end

  def run_test_failure_fields
    failed_test = payload[:failed_test]
    [
      {
        title: "Failed Test",
        value: "<#{failed_test[:frontend_url]} | Test ##{failed_test[:id]}: #{failed_test[:title]}>",
        short: true
      },
      { title: "Environment", value: run[:environment][:name], short: true },
      { title: "Browser", value: payload[:browser][:full_name], short: true }
    ]
  end

  def test_percentage(test_quantity)
    ((test_quantity.to_f / run[:total_tests].to_f).round(2) * 100).to_i
  end

  def message_color
    return 'danger' if run[:result] == 'failed'

    color_hash = {
      'run_completion' => "good",
      'run_error' => "danger",
      'webhook_timeout' => "danger",
      'run_test_failure' => "danger",
    }

    color_hash[event_type]
  end

  # overwriting generic format for slack hyperlink format
  def run_href
    "<#{payload[:frontend_url]} | Run ##{run[:id]}#{run_description}>"
  end
end
