config = {
  host: "#{ Rails.application.credentials.elasticsearch[:awsdev][:url] }",
  transport_options: {
    request: { timeout: 5 }
  }
}

if File.exists?("config/elasticsearch.yml")
  #config.merge!(YAML.load_file("config/elasticsearch.yml")[Rails.application.credentials.rails_env].deep_symbolize_keys)
end

Elasticsearch::Model.client = Elasticsearch::Client.new(config)
