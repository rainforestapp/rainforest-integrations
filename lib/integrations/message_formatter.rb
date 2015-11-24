module Integrations
  module MessageFormatter
    def message_text
      message = self.send(event_type.dup.concat("_message").to_sym)
      "Your Rainforest Run (#{run_href}) #{message}"
    end

    def run_href
      "Run ##{run[:id]}#{run_description} - #{payload[:frontend_url]}"
    end

    def test_href
      failed_test = payload[:failed_test]
      "Test ##{failed_test[:id]}: #{failed_test[:title]} - #{failed_test[:frontend_url]} (#{payload[:browser]})"
    end

    def run_description
      run[:description] ? ": #{run[:description]}" : ""
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

    def humanize_secs(seconds)
      secs = seconds.to_i
      [[60, :seconds], [60, :minutes], [24, :hours], [1000, :days]].map do |count, name|
        if secs > 0
          secs, n = secs.divmod(count)
          "#{n.to_i} #{name}"
        end
      end.compact.reverse.join(', ')
    end
  end
end
