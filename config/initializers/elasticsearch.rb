=begin
require 'aws-sdk-elasticsearchservice'

config = {
  host: "#{ Rails.application.credentials.elasticsearch[ENV["RAILS_ENV"].to_sym][:url] }",
  transport_options: {
    request: { timeout: 5 }
  }
}

if File.exists?("config/elasticsearch.yml")
  config.merge!(YAML.load_file("config/elasticsearch.yml")[ENV["RAILS_ENV"]].deep_symbolize_keys)
end

Elasticsearch::Model.client = Elasticsearch::Client.new(config)
=end
