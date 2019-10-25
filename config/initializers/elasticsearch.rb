case ENV["RAILS_ENV"]
when "production" || "awsdev"
	config = {
	  hosts: {host: Rails.application.credentials.elasticsearch[ENV["RAILS_ENV"].to_sym][:url], port: '80'},
	  transport_options: {
	     request: { timeout: 5 }
	  }
	}
else
	config = {
	  host: "#{ Rails.application.credentials.elasticsearch[ENV["RAILS_ENV"].to_sym][:url] }",
	  transport_options: {
	    request: { timeout: 5 }
	  }
	}
	
	if File.exists?("config/elasticsearch.yml")
	  config.merge!(YAML.load_file("config/elasticsearch.yml")[ENV["RAILS_ENV"]].deep_symbolize_keys)
	end
end

Elasticsearch::Model.client = Elasticsearch::Client.new(config)
