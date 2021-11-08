##
# Policy Type Model
# file: +app/models/policy_type.rb+

class PolicyType < ApplicationRecord
  include SetSlug

  RESIDENTIAL_ID = 1
  MASTER_ID = 2
  MASTER_COVERAGE_ID = 3
  COMMERCIAL_ID = 4
  RENT_GUARANTEE_ID = 5
  SECURITY_DEPOSIT_ID = 6
  MASTER_SECURITY_DEPOSIT_ID = 7
  MASTER_SECURITY_COVERAGE_ID = 8

  MASTER_IDS = [MASTER_ID, MASTER_SECURITY_DEPOSIT_ID].freeze
  MASTER_COVERAGES_IDS = [MASTER_COVERAGE_ID, MASTER_SECURITY_COVERAGE_ID].freeze
  MASTER_TYPES_IDS = [MASTER_ID, MASTER_COVERAGE_ID].freeze

  MASTER_MUTUALLY_EXCLUSIVE = {
    MASTER_ID => [RESIDENTIAL_ID, MASTER_COVERAGE_ID],
    MASTER_SECURITY_DEPOSIT_ID => [SECURITY_DEPOSIT_ID, MASTER_SECURITY_COVERAGE_ID]
  }.freeze

  after_initialize :initialize_policy_type

  # Relationships

  belongs_to :master_policy, class_name: 'PolicyType', optional: true
  has_many :carrier_policy_types
  has_many :carriers,
    through: :carrier_policy_types

  has_many :commission_strategies
  has_many :billing_strategies
  has_many :master_coverages, class_name: 'PolicyType', foreign_key: :master_policy_id

  # Validations
  validates :title, presence: true, uniqueness: true
  validates_presence_of :slug
  # validates :designation, presence: true,
  #                         uniqueness: true
  #
  scope :master, -> { where(master: true) }
  scope :master_coverages, -> { where(master_coverage: true) }
  scope :master_and_coverages, -> { where(master: true).or where(master_coverage: true) }

  def master_policy?
    master
  end

  def coverage
    master_coverages.take
  end

  def residential?
    self.designation == 'HO4'
  end

  def rent_guarantee?
    self.designation == 'RENT-GUARANTEE'
  end

  def master_coverage?
    self.designation == 'MASTER-COVERAGE'
  end

  def commercial?
    self.designation == 'BOP'
  end

  def security_deposit?
    self.designation == 'SECURITY-DEPOSIT'
  end

  class << self
    def residential
      find_by!(slug: 'residential')
    end

    def rent_garantee
      find_by!(slug: 'rent-guarantee')
    end

    def security_deposit
      find_by!(slug: 'security-deposit-replacement')
    end
  end

  private

  def initialize_policy_type
    self.enabled = false if enabled.nil?
  end
end
