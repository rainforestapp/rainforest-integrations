require 'raven'

Raven.configure do |config|
  config.dsn = ENV.fetch('INTEGRATION_SENTRY_DSN')
  config.tags = { environment: Rails.env }
  config.environments = %w[ production staging qa ]
end
