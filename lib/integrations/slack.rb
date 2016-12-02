# frozen_string_literal: true
class Integrations::Slack < Integrations::Base
  SUPPORTED_EVENTS = %w(run_completion run_error webhook_timeout run_test_failure integration_test).freeze

  def message_text(fallback = false, test = false)
    message = self.send(event_type.dup.concat('_message').to_sym)
    if test
      integration_test_message
    elsif fallback
      "Your Rainforest Run #{message}"
    else
      "Your Rainforest Run (<#{payload[:frontend_url]} | Run ##{run[:id]}#{run[:description].present? ? ": #{run[:description]}" : ""}>) #{message}"
    end
  end

  def run_completion_message
    'is complete!'
  end

  def run_error_message
    'has encountered an error!'
  end

  def webhook_timeout_message
    "has timed out due to a webhook failure!\nIf you need a hand debugging it, please let us know via email at help@rainforestqa.com."
  end

  def run_test_failure_message
    'has a failed test!'
  end

  def test_percentage(test_quantity)
    ((test_quantity.to_f / run[:total_tests].to_f).round(2) * 100).to_i
  end

  def self.key
    'slack'
  end

  def send_event
    return unless SUPPORTED_EVENTS.include?(event_type)
    return unless ok_to_send_event?
    response = HTTParty.post(settings[:url],
                             body: {
                               attachments: attachments
                             }.to_json,
                             headers: {
                               'Content-Type' => 'application/json',
                               'Accept' => 'application/json'
                             }
                            )

    if response.code == 500 && response.parsed_response == 'no_text'
      raise Integrations::Error.new('user_configuration_error', 'Invalid request to the Slack API (maybe the JSON structure is wrong?).', response)
    elsif response.code == 404 && response.parsed_response == 'Bad token'
      raise Integrations::Error.new('user_configuration_error', 'The provided Slack URL is invalid.', response)
    elsif response.code != 200
      raise Integrations::Error.new('misconfigured_integration', 'Invalid request to the Slack API.', response)
    end
  end

  private

  def ok_to_send_event?
    settings[:url].present?
  end

  def attachments
    case event_type
    when 'run_completion'
      attachment = run_completion_fields
    when 'run_error'
      attachment = run_error_fields
    when 'run_test_failure'
      attachment = run_test_failure_fields
    when 'webhook_timeout'
      attachment = webhook_timeout_fields
    when 'integration_test'
      attachment = integration_test
    end

    unless event_type == 'integration_test'
      attachment.merge!(
        fallback: message_text(fallback: true),
        text: message_text
      )
    end
    return [attachment]
  end

  # The order here intentionally 'alternates' between run info and tests info because
  # it's laid out better in slack's table-format that way
  def run_completion_fields
    color = run[:result] == 'passed' ? 'good' : 'danger'
    {
      color: color,
      fields: [
        { title: 'Result', value: run[:result].humanize, short: true },
        {
          title: "Tests Passed: #{run[:total_passed_tests]} - #{test_percentage(run[:total_passed_tests])}%",
          value: "<#{payload[:frontend_url]}?expandedGroups%5B%5D=passed | View all Passed tests>",
          short: true
        },
        { title: 'Duration', value: humanize_secs(run[:time_taken]), short: true },
        {
          title: "Tests Failed: #{run[:total_failed_tests]} - #{test_percentage(run[:total_failed_tests])}%",
          value: "<#{payload[:frontend_url]}?expandedGroups%5B%5D=failed | View all Failed tests>",
          short: true
        },
        { title: 'Environment', value: run[:environment][:name], short: true },
        {
          title: "Other Results: #{run[:total_no_result_tests]} - #{test_percentage(run[:total_no_result_tests])}%",
          value: "<#{payload[:frontend_url]}?expandedGroups%5B%5D=no_result | View all tests with no result>",
          short: true
        }
      ]
    }
  end

  def run_error_fields
    if run[:error_reason].nil? || run[:error_reason].empty?
      run[:error_reason] = "Error reason was unspecified (please contact help@rainforestqa.com if you'd like help debugging this)"
    end
    {
      color: 'danger',
      fields: [{ title: 'Error Reason', value: run[:error_reason], short: false }]
    }

  end

  def run_test_failure_fields
    failed_test = payload[:failed_test]
    fields = [
      {
        title: 'Failed Test',
        value: "<#{failed_test[:frontend_url]} | Test ##{failed_test[:id]}: #{failed_test[:title]}>",
        short: true
      },
      { title: 'Environment', value: run[:environment][:name], short: true },
      { title: 'Browser', value: payload[:browser][:description], short: true }
    ]

    payload[:feedback].each do |feedback|
      fields << {
        title: "Feedback from #{feedback[:worker_name]}",
        value: feedback[:note],
        short: false
      }
    end

    {
      color: 'danger',
      fields: fields
    }
  end

  def webhook_timeout_fields
    {
      color: 'danger',
      fields: [{ title: 'Environment', value: run[:environment][:name], short: false }]
    }
  end

  def integration_test
    {
      color: 'good',
      fields: [],
      fallback: 'Your slack integration works!',
      text: 'Your slack integration works!'
    }
  end
end
