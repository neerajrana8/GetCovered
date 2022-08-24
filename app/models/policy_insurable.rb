# == Schema Information
#
# Table name: policy_insurables
#
#  id                    :bigint           not null, primary key
#  value                 :integer          default(0)
#  primary               :boolean          default(FALSE)
#  current               :boolean          default(FALSE)
#  policy_id             :bigint
#  policy_application_id :bigint
#  insurable_id          :bigint
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  auto_assign           :boolean          default(FALSE)
#
# Policy Insurable Model
# file: app/models/policy_insurable.rb
#
# Model serves as a join association between a policy and insurables.

class PolicyInsurable < ApplicationRecord
  before_create :set_first_as_primary
  
  belongs_to :policy_application, optional: true
  belongs_to :policy, optional: true
  belongs_to :insurable
  
  validate :one_primary_per_insurable
  validate :residential_unit_coverage_for_master_coverage_policy
  
  def residential_unit_coverage_for_master_coverage_policy
    if policy&.policy_type&.designation == 'MASTER-COVERAGE' && primary == true
      if  insurable&.insurable_type&.id != 4
        errors.add(:insurable, 'must be a Residential Unit')
      end

      if  insurable.leases&.count == 0
        errors.add(:insurable, 'must be occupied')
      end

      if insurable&.parent_community&.policies&.where(policy_type_id: PolicyType::MASTER_ID).count&.positive?
        errors.add(:insurable, 'must have Master Policy')
      end
    end
  end
  
  
  private
  
  def set_first_as_primary
    query_model = policy.nil? ? policy_application : policy
    self.primary = true if query_model&.insurables&.count == 0
  end
  
  def one_primary_per_insurable
    #       if primary == true
    #         errors.add(:primary, "one primary insurable per policy") if policy.insurables.count >= 1   
    #       end  
  end
end
