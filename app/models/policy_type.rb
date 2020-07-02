##
# Policy Type Model
# file: +app/models/policy_type.rb+

class PolicyType < ApplicationRecord
  include SetSlug

  MASTER_ID = 2
  MASTER_COVERAGE_ID = 3

  after_initialize :initialize_policy_type
  
  # Relationships
  has_many :carrier_policy_types
  has_many :carriers, 
    through: :carrier_policy_types
  
  has_many :commission_strategies
  has_many :billing_strategies
  
  # Validations
  validates :title, presence: true, uniqueness: true
  validates_presence_of :slug
  # validates :designation, presence: true,
  #                         uniqueness: true
  #
  scope :master_policies, -> { where("title LIKE 'Master%'") }

  def master_policy?
    designation == 'MASTER'
  end


  class << self
    def residential
      find_by!(slug: 'residential')
    end
  end

  private
  
  def initialize_policy_type
    self.enabled = false if enabled.nil?
  end
end
