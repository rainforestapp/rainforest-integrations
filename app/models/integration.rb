require 'yaml'

class Integration
  INTEGRATIONS = YAML.load(File.read(Rails.root.join('data', 'integrations.yml'))).freeze
  EVENT_TYPES = YAML.load(File.read(Rails.root.join('data', 'event_types.yml'))).freeze

  # NOTE: Temporarily obscure integrations that aren't ready yet
  INCOMPLETE_INTEGRATIONS = %w(pivotal_tracker).freeze

  class NotFound < StandardError
  end

  def self.find(key)
    data = INTEGRATIONS.fetch(key) do
      raise NotFound, %(Integration "#{key}" is not supported)
    end

    { 'key' => key }.merge data
  end

  def self.exists?(key)
    INTEGRATIONS.key? key
  end

  def self.keys
    INTEGRATIONS.keys
  end

  def self.supported_integrations
    INTEGRATIONS.map {|key, data| { 'key' => key }.merge data }
  end

  def self.public_integrations
    supported_integrations.reject { |int| INCOMPLETE_INTEGRATIONS.include?(int['key']) }
  end

  def self.supported_event_types
    EVENT_TYPES
  end
end
