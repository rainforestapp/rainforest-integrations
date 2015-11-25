module Integrations
  class Error < StandardError
    attr_reader :type, :message

    def initialize(type="unknown_error", message="Unknown Error")
      @type = type
      @message = message
      super message
    end
  end

  def self.send_event(event_type: , integrations: , payload: )
    PayloadValidator.new(event_type, integrations, payload).validate!

    integrations.each do |integration|
      integration_name = integration[:key]
      raise Error.new('unsupported_integration', "Integration #{integration_name} does not exist") unless Integration.exists?(integration_name)

      klass_name = "Integrations::#{integration_name.classify}".constantize
      integration_object = klass_name.new(event_type, payload, integration[:settings])
      integration_object.send_event
    end
  end
end
