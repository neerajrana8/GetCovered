class InsurableType < ApplicationRecord
  include ElasticsearchSearchable
  include SetSlug

  COMMUNITIES_IDS = [1, 2, 3].freeze
  UNITS_IDS = [4, 5].freeze
  BUILDINGS_IDS = [7].freeze

  RESIDENTIAL_COMMUNITIES_IDS = [1, 2].freeze
  RESIDENTIAL_UNITS_IDS = [4].freeze

  COMMERCIAL_COMMUNITIES_IDS = [2, 3].freeze

  has_many :insurables
  has_many :carrier_insurable_types
  has_many :least_type_insurable_types

  scope :units, -> { where(id: UNITS_IDS) }
  scope :communities, -> { where(id: COMMUNITIES_IDS) }
  scope :buildings, -> { where(id: BUILDINGS_IDS) }
  
  validates_presence_of :title, :slug, :category
  validates_inclusion_of :enabled,
                         in: [true, false], message: 'cannot be blank'

  enum category: %w[property entity]
end
