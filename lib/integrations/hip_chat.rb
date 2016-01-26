
class Integrations::HipChat < Integrations::Base
  def self.key
    "hip_chat"
  end

  def send_event
    room = HipChat::Room.new(
      settings[:room_token],
      room_id: settings[:room_id],
      api_version: 'v2',
      server_url: 'https://api.hipchat.com' # TODO: Make this configurable
    )


    # TODO: make notify configurable
    begin
      room.send('Rainforest QA', message, notify: true, color: color)
    rescue HipChat::ServiceError => e
      # ServiceError is the parent class for all of HipChat's errors. For
      # greater specificity, please see:
      # https://github.com/hipchat/hipchat-rb/blob/master/lib/hipchat/errors.rb
      raise Integrations::Error.new('service_error', e.message)
    end
  end

  private

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

  def run_completion_message
    <<-HTML
Rainforest <a href="#{payload[:frontend_url]}">Run ##{run[:id]}</a> is complete!
Result: <b>#{run[:result]}</b>
    HTML
  end

  def run_error_message
    <<-HTML
Rainforest <a href="#{payload[:frontend_url]}">Run ##{run[:id]}</a> has encountered an error!
Please contact #{CUSTOMER_SERVICE_EMAIL} for more details.
    HTML
  end

  def webhook_timeout_message
    <<-HTML
Rainforest <a href="#{payload[:frontend_url]}">Run ##{run[:id]}</a> has has timed out!
Please contact #{CUSTOMER_SERVICE_EMAIL} if you need help debugging this problem.
    HTML
  end
end
