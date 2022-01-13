class InsurableType < ApplicationRecord
  include SetSlug

  COMMUNITIES_IDS = [1, 2, 3].freeze
  UNITS_IDS = [4, 5].freeze
  BUILDINGS_IDS = [7].freeze

  RESIDENTIAL_COMMUNITIES_IDS = [1, 2].freeze
  RESIDENTIAL_BUILDINGS_IDS = [7].freeze
  RESIDENTIAL_UNITS_IDS = [4].freeze
  RESIDENTIAL_IDS = [1, 2, 4, 7].freeze

  COMMERCIAL_COMMUNITIES_IDS = [2, 3].freeze

  after_save :refresh_insurable_policy_type_ids,
    if: Proc.new{|it| it.saved_change_to_attribute?(:policy_type_ids) }

  has_many :insurables
  has_many :carrier_insurable_types
  has_many :least_type_insurable_types

  scope :units, -> { where(id: UNITS_IDS) }
  scope :communities, -> { where(id: COMMUNITIES_IDS) }
  scope :buildings, -> { where(id: BUILDINGS_IDS) }

  validates_presence_of :title, :slug, :category
  validates_inclusion_of :enabled,
                         in: [true, false], message: I18n.t('insurable_type_model.cannot_be_blank')

  enum category: %w[property entity]

  def refresh_insurable_policy_type_ids
    RefreshInsurablePolicyTypeIdsJob.perform_later(self.insurables)
  end
end
