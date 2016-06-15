# frozen_string_literal: true
module Integrations
  class Error < StandardError
    attr_reader :type, :message, :response_body, :response_code

    def initialize(type='unknown_error', message='Unknown Error', response)
      @type = type
      @message = message
      if response && response.respond_to?(:body)
        @response_body = response.body
        @response_code = response.code
      end
      super message
    end
  end

  def self.send_event(event_type:, integrations:, payload:, oauth_consumer:)
    PayloadValidator.new(event_type, integrations, payload).validate!

    integrations.each do |integration|
      integration_name = integration[:key]
      unless Integration.exists?(integration_name)
        raise Error.new('unsupported_integration', "Integration #{integration_name} does not exist")
      end

      klass_name = "Integrations::#{integration_name.classify}".constantize
      integration_object = klass_name.new(event_type, payload, integration[:settings], oauth_consumer)
      integration_object.send_event if integration_object.valid?
    end
  end
end
