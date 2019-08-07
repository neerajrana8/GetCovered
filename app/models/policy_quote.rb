# frozen_string_literal: true

class PolicyQuote < ApplicationRecord
  # Concerns
  include CarrierQbeQuote, ElasticsearchSearchable

  belongs_to :policy_application, optional: true
  belongs_to :agency, optional: true
  belongs_to :account, optional: true
  belongs_to :policy, optional: true

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :reference, type: :text, analyzer: 'english'
      indexes :external_reference, type: :text, analyzer: 'english'
    end
  end
end
