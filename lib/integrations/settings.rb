module Integrations
  class Settings
    attr_reader :settings

    def initialize(settings)
      @settings = settings
    end

    def [](key)
      setting = settings.detect{ |s| s[:key] == key.to_s }
      return nil if setting.nil?
      setting.fetch(:value)
    end

    def keys
      setting = settings.map { |s| s[:key] }
    end
  end
end
