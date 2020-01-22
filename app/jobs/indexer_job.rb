##
# Indexer Job

class IndexerJob < ApplicationJob
  rescue_from(StandardError) do |exception|
    Rails.logger.error "[#{self.class.name}] Hey, something was wrong with you job #{exception.to_s}"       
  end 

  queue_as :elasticsearch

  Logger = Sidekiq.logger.level == Logger::DEBUG ? Sidekiq.logger : nil
  Client = Elasticsearch::Client.new host: (Rails.application.credentials.elasticsearch[ENV["RAILS_ENV"].to_sym][:url] || 'http://elasticsearch:9200'), logger: Logger

  def perform(klass, index_name, operation, record_id)
    logger.debug [operation, "ID: #{record_id}"]

    case operation.to_s
      when /index/
        record = klass.find(record_id)
        record.__elasticsearch__.client = Client
        record.__elasticsearch__.index_document
      when /update/
        record = klass.find(record_id)
        record.__elasticsearch__.client = Client
        record.__elasticsearch__.update_document
      when /delete/
        Client.delete index: index_name, type: klass.__elasticsearch__.document_type, id: record_id, ignore: 404
      else raise ArgumentError, "Unknown operation '#{operation}'"
    end
  end 
end