Rails.application.config.middleware.insert_before Rack::Runtime, Rack::Timeout, service_timeout: 110, wait_timeout: 110
