# frozen_string_literal: true

# ElasticsearchSearchable Concern
module ElasticsearchSearchable
  extend ActiveSupport::Concern
  included do
    include Elasticsearch::Model
    include Elasticsearch::Model::Callbacks
    include Elasticsearch::Model::Indexing

    name = self.name.downcase.pluralize
    index_name = "get-covered-#{name}-#{Rails.env}"

    index_name index_name

    after_commit on: [:create] do
      IndexerJob.perform_now(self.class, index_name, :index, id)
    end

    after_commit on: [:update] do
      IndexerJob.perform_now(self.class, index_name, :update, id)
    end

    after_commit on: [:destroy] do
      IndexerJob.perform_now(self.class, index_name, :delete, id)
    end
  end
end
