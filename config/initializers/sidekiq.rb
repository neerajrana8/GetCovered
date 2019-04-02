sidekiq_config = { 
	:host => ENV.fetch("JOB_WORKER_URL"),
	:port => ENV.fetch("JOB_WORKER_PORT") 
}

Sidekiq.configure_server do |config|
  config.redis = sidekiq_config
end

Sidekiq.configure_client do |config|
  config.redis = sidekiq_config
end