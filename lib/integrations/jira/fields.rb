# frozen_string_literal: true
class Integrations::Jira::Fields
  attr_reader :access_token

  def initialize(access_token)
    @access_token = access_token
  end

  def enabled_fields
    @enabled_fields ||= get_enabled_fields
  end

  def get_enabled_fields
    # Endpoint docs: https://docs.atlassian.com/jira/REST/latest/#api/2/field-getFields
    response = oauth_access_token.get("#{jira_base_url}/rest/api/2/field")
    validate_response(response)

    fields = MultiJson.load(response.body, symbolize_keys: true)
    fields.select { |f| JIRA_FIELDS.include?(f['id']) }
  end

  def labels_searchable?
    labels_field = enabled_fields.find { |f| f['id'] == 'labels' }
    !!labels_field && labels_field['searchable']
  end
end
