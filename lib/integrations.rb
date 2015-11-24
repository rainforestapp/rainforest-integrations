module Integrations
  Integration.keys.each { |i| require "integrations/#{i}" }

  class UnsupportedIntegrationError < StandardError
    def initialize(integration_name)
      super "Integration '#{integration_name}' is not supported"
    end
  end

  class UnsupportedEventError < StandardError
    def initialize(event_name)
      super "Integration '#{event_name}' is not supported"
    end
  end

  class MisconfiguredIntegrationError < StandardError
  end

  class UserConfigurationError < StandardError
  end

  def self.send_event(event_type: , integrations: , payload: )
    PayloadValidator.new(event_type, integrations, payload).validate!

    integrations.each do |integration|
      integration_name = integration[:key]
      raise UnsupportedIntegrationError, integration_name unless Integration.exists? integration_name

      klass_name = "Integrations::#{integration_name.classify}".constantize
      integration_object = klass_name.new(event_type, payload, integration[:settings])
      integration_object.send_event
    end
  end
end
