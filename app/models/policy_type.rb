##
# Policy Type Model
# file: +app/models/policy_type.rb+

class PolicyType < ApplicationRecord
  include SetSlug
  
  after_initialize :initialize_policy_type
  
  # Relationships
  has_many :carrier_policy_types
  has_many :carriers, 
    through: :carrier_policy_types
  
  has_many :commission_strategies
  
  # Validations
  validates :title, presence: true, uniqueness: true
  # validates :designation, presence: true,
  #                         uniqueness: true      

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
