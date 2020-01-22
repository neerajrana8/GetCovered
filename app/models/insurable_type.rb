class InsurableType < ApplicationRecord
  include ElasticsearchSearchable

  COMMUNITIES_IDS = [1, 2, 3]
  UNITS_IDS = [4, 5, 6]

  has_many :insurables
  has_many :carrier_insurable_types
  has_many :least_type_insurable_types

  scope :units, -> { where(id: UNITS_IDS) }
  scope :communities, -> { where(id: COMMUNITIES_IDS) }

  enum category: %w[property entity]
end
