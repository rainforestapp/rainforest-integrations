require "active_support/core_ext/string/strip"

module Rainforest::Integrations
  module HtmlRenderer

    def render_html(event)
      case event.name
      when "of_run_completion"                then completion_html(event)
      when "of_run_error"                     then error_html(event)
      when "of_test_failure"                  then failure_html(event)
      when "of_run_timeout_because_of_webook" then webhook_timeout_html(event)
      end
    end

    def completion_html(event)
      <<-HTML.strip_heredoc
        Your Rainforest Run #{event.run["id"]}#{run_description(event.run)} #{event.run["result"]} -
          <a href="#{event.ui_link}">view the results here</a>
      HTML
    end

    def error_html(event)
      <<-HTML.strip_heredoc
        Your Rainforest run #{link_to_run(event.run, event.ui_link)}#{run_description(event.run)}
        just errored: '#{event.run["error_reason"]}'
      HTML
    end

    def failure_html(event)
      <<-HTML.strip_heredoc
        Your test '#{event.browser_result["failing_test"]["title"]}'
        just failed in #{event.browser_result["name"]} -
        <a href='#{event.ui_link}'>view the failure here</a>.
      HTML
    end

    def webhook_timeout_html(event)
      <<-HTML.strip_heredoc
       Your Rainforest run #{link_to_run(event.run, event.ui_link)}#{run_description(event.run)} timed out due to your webhook failing. If you need a hand debugging it, please let us know via email <a href="mailto:team@rainforestqa.com">team@rainforestqa.com</a>.
      HTML
    end

    def link_to_run(run, href)
      %{<a href="#{href}">#{run["id"]}</a>}
    end

    def run_description(run)
      unless run["description"].nil? or run["description"].empty?
        %{ (#{run["description"]})}
      end
    end
  end
end
