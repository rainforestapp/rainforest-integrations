# frozen_string_literal: true
module Integrations
  class Base
    CUSTOMER_SERVICE_EMAIL = 'help@rainforestqa.com'
    attr_reader :event_type, :payload, :settings, :run, :oauth_consumer

    def initialize(event_type, payload, settings, oauth_consumer)
      @event_type = event_type
      @payload = payload
      @run = payload[:run] || {}
      @settings = Integrations::Settings.new(settings)
      @oauth_consumer = oauth_consumer
    end

    # this key should match the key used to identify the integration in integrations.yml
    def self.key
      raise 'key must be defined in the child class'
    end

    def self.required_settings
      @required_settings ||= Integration.find(key).fetch('settings').map do |setting|
        if setting['required']
          setting.fetch('key')
        end
      end.compact
    end

    # send_event will be the public facing method for all integrations. Please
    # overwrite with your custom behavior
    def send_event
      raise 'send_event must be defined in the child class'
    end

    def humanize_secs(seconds)
      secs = seconds.to_i
      time_string = [[60, :seconds], [60, :minutes], [24, :hours], [1000, :days]].map do |count, name|
        if secs > 0
          secs, n = secs.divmod(count)
          "#{n.to_i} #{name}"
        end
      end.compact.reverse.join(', ')
      # Fallback in case seconds == 0
      time_string.empty? ? 'Error/Unknown' : time_string
    end

    def valid?
      supplied_settings = settings.keys
      required_settings = self.class.required_settings
      missing_settings = required_settings - supplied_settings

      unless missing_settings.empty?
        log_error("Required settings were missing: #{missing_settings.join(', ')}")
        false
      else
        true
      end
    end

    # Used for debug purposes
    def to_s
      "Event Type: #{event_type}, Payload: #{payload}, Settings: #{settings}"
    end

    protected

    def log_error(msg)
      log(:error, msg)
    end

    def log_info(msg)
      log(:info, msg)
    end

    def log(level, msg)
      Rails.logger.public_send(level, "#{msg} - Debug: #{self}")
    end
  end
end
