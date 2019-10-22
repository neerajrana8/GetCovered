sidekiq_config = { 
	:host => Rails.application.credentials.redis[Rails.application.credentials.rails_env.to_sym][:host],
	:port => Rails.application.credentials.redis[Rails.application.credentials.rails_env.to_sym][:port] 
}

Sidekiq.configure_server do |config|
  config.redis = sidekiq_config
end

Sidekiq.configure_client do |config|
  config.redis = sidekiq_config
end