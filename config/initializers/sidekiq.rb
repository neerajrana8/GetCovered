sidekiq_config = {
  host: Rails.application.credentials.redis[ENV['RAILS_ENV'].to_sym][:host],
  port: Rails.application.credentials.redis[ENV['RAILS_ENV'].to_sym][:port]
}

Sidekiq.configure_server do |config|
  config.redis = sidekiq_config
  config.on(:startup) do
    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end
end

Sidekiq.configure_client do |config|
  config.redis = sidekiq_config
end
