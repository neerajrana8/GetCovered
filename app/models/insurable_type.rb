class InsurableType < ApplicationRecord
  include ElasticsearchSearchable
  has_many :insurables
  has_many :carrier_insurable_types
  has_many :least_type_insurable_types

  scope :units, -> { where("title LIKE '%Unit'") }
  scope :communities, -> { where("title LIKE '%Community'") }

  enum category: %w[property entity]
end
