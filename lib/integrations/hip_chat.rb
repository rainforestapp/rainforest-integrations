# frozen_string_literal: true
class Integrations::HipChat < Integrations::Base
  def self.key
    'hip_chat'
  end

  def send_event
    unless ok_to_send_event?
      log_info("Unable to send hipchat message!")
      return
    end

    room = HipChat::Room.new(
      settings[:room_token],
      room_id: settings[:room_id],
      api_version: 'v2',
      server_url: 'https://api.hipchat.com' # TODO: Make this configurable
    )

    # TODO: make notify configurable
    begin
      room.send(
        'Rainforest QA',
        message,
        card: card,
        notify: true,
        color: color
      )
    rescue HipChat::ServiceError => e
      # ServiceError is the parent class for all of HipChat's errors. For
      # greater specificity, please see:
      # https://github.com/hipchat/hipchat-rb/blob/master/lib/hipchat/errors.rb
      raise Integrations::Error.new('service_error', e.message)
    end
  end

  private

  def card
    {
      id: SecureRandom.uuid,
      style: 'application',
      icon: {
        url: 'https://www.rainforestqa.com/images/favicon-f246a1f7.png'
      }
    }.merge(self.send(:"#{event_type}_card"))
  end

  def ok_to_send_event?
    settings[:room_token].present? && settings[:room_id].present?
  end

  def color
    case event_type
    when 'run_completion' then run[:result] == 'passed' ? 'green' : 'red'
    when 'run_error', 'run_test_failure', 'webhook' then 'red'
    end
  end

  def message
    self.send(:"#{event_type}_message")
  end

  def run_test_failure_message
    failed_test = payload[:failed_test]
    <<-HTML
Rainforest <a href="#{payload[:frontend_url]}">Run ##{run[:id]}</a> has a failed test!
Failed Test: <a href="#{failed_test[:frontend_url]}">#{failed_test[:title]}</a>
    HTML
  end

  def run_test_failure_card
    failed_test = payload[:failed_test]

    {
      title: "Your Rainforest Run (##{run[:id]}) has failed a test!",
      url: failed_test[:frontend_url],
      attributes: [
        {
          label: "Failed Test",
          value: { label: "#{failed_test[:title]} (##{failed_test[:id]})" }
        },
        {
          label: 'Environment',
          value: { label: run[:environment][:name] }
        },
        {
          label: 'Browser',
          value: { label: payload[:browser][:description] }
        }
      ]
    }
  end

  def run_completion_message
    <<-HTML
Rainforest <a href="#{payload[:frontend_url]}">Run ##{run[:id]}</a> is complete!
Result: <b>#{run[:result]}</b>
    HTML
  end

  def run_completion_card
    {
      title: "Your Rainforest Run (##{run[:id]}) is complete!",
      url: payload[:frontend_url],
      attributes: [
        {
          label: 'Result',
          value: { label: run[:result].humanize }
        },
        {
          label: 'Environment',
          value: { label: run[:environment][:name] }
        },
        {
          label: "Duration",
          value: { label: humanize_secs(run[:time_taken]) }
        }
      ]
    }
  end

  def run_error_message
    <<-HTML
Rainforest <a href="#{payload[:frontend_url]}">Run ##{run[:id]}</a> has encountered an error!
Please contact #{CUSTOMER_SERVICE_EMAIL} for more details.
    HTML
  end

  def run_error_card
    {
      title: "Your Rainforest Run (##{run[:id]}) has encountered an error!",
      url: payload[:frontend_url],
      attributes: [
        {
          label: 'Error Reason',
          value: { label: run[:error_reason] }
        }
      ]
    }
  end

  def webhook_timeout_message
    <<-HTML
Rainforest <a href="#{payload[:frontend_url]}">Run ##{run[:id]}</a> has timed out!
Please contact #{CUSTOMER_SERVICE_EMAIL} if you need help debugging this problem.
    HTML
  end

  def webhook_timeout_card
    {
      title: "Your Rainforest Run (##{run[:id]}) has timed out!",
      url: payload[:frontend_url],
      attributes: [
        {
          label: 'Environment',
          value: { label: run[:environment][:name] }
        }
      ]
    }
  end
end
