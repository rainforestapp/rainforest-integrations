# frozen_string_literal: true
class PayloadValidator
  EVENTS = YAML.load File.read(Rails.root.join('data', 'events.yml')).freeze

  class InvalidPayloadError < StandardError
  end

  def initialize(event_type, integrations, payload)
    @event_type = event_type
    @integrations = integrations
    @payload = payload
  end

  def validate!
    # integration_test doens't have a payload
    return true if @event_type.to_s == "integration_test"
    event = EVENTS.fetch(@event_type.to_s) do
      raise InvalidPayloadError, "Event #{@event_type} is not supported"
    end
    raise InvalidPayloadError, 'payload must be properly formatted JSON' unless @payload.is_a? Hash
    raise InvalidPayloadError, 'integrations must be an array' unless @integrations.is_a? Array

    keys = event['payload'].keys.map(&:to_sym)
    unless keys & @payload.keys == keys
      missing = (keys - @payload.keys).map { |key| "'#{key}'" }.join(', ')
      raise InvalidPayloadError, "Payload for event #{@event_type} did not contain required keys: #{missing}"
    end
  end
end
