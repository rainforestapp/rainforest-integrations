# frozen_string_literal: true
class Integrations::PivotalTracker < Integrations::Base
  include HTTParty

  PIVOTAL_API_URL = 'https://www.pivotaltracker.com/services/v5'
  SUPPORTED_EVENTS = %w(webhook_timeout run_test_failure integration_test).freeze
  FINAL_STORY_STATES = %w(delivered accepted).freeze

  def self.key
    'pivotal_tracker'
  end

  # TODO: Don't make the class base URI dynamic - race conditions waiting to happen
  def initialize(event_type, payload, settings, oauth_consumer)
    super
    self.class.base_uri "#{PIVOTAL_API_URL}/projects/#{self.settings[:project_id]}"
  end

  def send_event
    unless ok_to_send_event?
      log_info("Unable to create or update story!")
      return
    end

    stories = search_for_existing_stories

    if stories.length > 0
      story = stories.first
      update_story(story[:id])
    else
      create_story
    end
  end

  private

  def ok_to_send_event?
    SUPPORTED_EVENTS.include?(event_type) &&
    settings[:project_id].present? &&
    settings[:api_token].present?
  end

  def search_for_existing_stories
    response = request(:get, '/search', query: {query: "label:#{story_label} -state:#{FINAL_STORY_STATES.join(',')}"})
    validate_response!(response)
    parsed_response = MultiJson.load(response.body, symbolize_keys: true)
    parsed_response[:stories][:stories]
  end

  def update_story(story_id)
    params = {}
    params[:labels] = [story_label, repeated_issue_label] if repeated_issue_label

    unless params.empty?
      response = request(:put, "/stories/#{story_id}", body: params)
      validate_response!(response)
    end
  end

  def create_story
    post_data = case event_type
                when 'webhook_timeout' then create_webhook_timeout_story
                when 'run_test_failure' then create_test_failure_story
                when 'integration_test' then create_integration_test_story
                end

    response = request(:post, '/stories', body: post_data)
    validate_response!(response)
  end

  def create_webhook_timeout_story
    run_info = "Run ##{run[:id]}"
    run_info += " (#{run[:description]})" if run[:description].present?

    {
      name: 'Your Rainforest webhook has timed out',
      description: "Your webhook has timed out for #{run_info}. If you need help debugging, please contact us at help@rainforestqa.com",
      story_type: 'bug',
      labels: [story_label],
      comments: [{text: "Environment: #{run[:environment][:name]}"}]
    }
  end

  def create_integration_test_story
    {
      name: 'Integration Test',
      description: 'Your slack integration works!',
      story_type: 'bug',
      labels: [story_label],
      comments: []
    }
  end

  def create_test_failure_story
    test = payload[:failed_test]

    {
      name: "Rainforest found a bug in '#{test[:title]}'",
      description: "Failed test title: #{test[:title]}\n#{payload[:frontend_url]}",
      story_type: 'bug',
      labels: [story_label],
      comments: [{text: "Environment: #{run[:environment][:name]}"}]
    }
  end

  def validate_response!(response)
    if response.code == 404
      raise Integrations::Error.new('user_configuration_error', 'The project ID provided was not found.', response)
    elsif response.code == 403
      raise Integrations::Error.new('user_configuration_error', 'The authorization token is invalid.', response)
    elsif response.code != 200
      raise Integrations::Error.new('user_configuration_error', 'Invalid request to the Pivotal Tracker API.', response)
    end
  end

  def request(method, path, options = {})
    self.class.send(
      method,
      path,
      options.merge(
        headers: {
          'X-TrackerToken' => settings[:api_token]
        }
      )
    )
  end

  def story_label
    case event_type
    when 'webhook_timeout' then "RfRun#{run[:id]}"
    when 'run_test_failure' then "RfTest#{payload[:failed_test][:id]}"
    when 'integration_test' then "Integration Test"
    end
  end

  def repeated_issue_label
    # Hard coded until custom values are in place
    'RepeatedFailures'
  end
end
