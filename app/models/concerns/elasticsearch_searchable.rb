# frozen_string_literal: true

# ElasticsearchSearchable Concern
module ElasticsearchSearchable
  extend ActiveSupport::Concern
  included do
    require 'elasticsearch/model'
    include Elasticsearch::Model
    include Elasticsearch::Model::Callbacks
    include Elasticsearch::Model::Indexing

    index_name "get-covered-#{name.downcase.pluralize}-#{Rails.env}"

    after_touch { __elasticsearch__.index_document }
  end
end
