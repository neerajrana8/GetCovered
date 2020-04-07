class InsurableType < ApplicationRecord
  include ElasticsearchSearchable
  include SetSlug

  COMMUNITIES_IDS = [1, 2, 3]
  UNITS_IDS = [4, 5]
  BUILDINGS_IDS = [7]

  RESIDENTIAL_COMMUNITIES_IDS = [1, 2]
  RESIDENTIAL_UNITS_IDS = [4]

  COMMERCIAL_COMMUNITIES_IDS = [2, 3]

  has_many :insurables
  has_many :carrier_insurable_types
  has_many :least_type_insurable_types

  scope :units, -> { where(id: UNITS_IDS) }
  scope :communities, -> { where(id: COMMUNITIES_IDS) }
  
  validates_presence_of :title, :slug, :category
  validates_inclusion_of :enabled,
    in: [true, false], message: 'cannot be blank'

  enum category: %w[property entity]
end
