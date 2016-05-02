# frozen_string_literal: true
module Integrations
  class Settings
    attr_reader :settings

    def initialize(settings)
      @settings = settings
    end

    def [](key)
      setting = settings.detect { |s| s[:key] == key.to_s }
      return nil if setting.nil?
      setting.fetch(:value)
    end

    def keys
      settings.each_with_object([]) { |s, key_arr| key_arr.push(s[:key]) if s[:value].present? }
    end

    def to_s
      settings.inspect
    end
  end
end
