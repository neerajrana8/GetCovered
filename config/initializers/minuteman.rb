Minuteman.configure do |config|
  # You need to use Redic to define a new Redis connection
  host = Rails.application.credentials.redis[ENV["RAILS_ENV"].to_sym][:host]
  port = Rails.application.credentials.redis[ENV["RAILS_ENV"].to_sym][:port]
  config.redis = Redic.new("redis://#{host}:#{port}/1")

  # The prefix affects operations
  config.prefix = "Tomato"

  # The patterns is what Minuteman uses for the tracking/counting and the
  # different analyzers
  config.patterns = {
      dia: -> (time) { time.strftime("%Y-%m-%d") }
  }
end

