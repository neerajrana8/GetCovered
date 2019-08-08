# Policy Insurable Model
# file: app/models/policy_insurable.rb
#
# Model serves as a join association between a policy and insurables.
# 

class PolicyInsurable < ApplicationRecord
	
	before_create :set_first_as_primary
	
  belongs_to :policy
  belongs_to :insurable
  
  validate :one_primary_per_insurable
  
  private
  	
  	def set_first_as_primary
	  	self.primary = true if policy.insurables.count == 0
	  end
	  
	  def one_primary_per_insurable
			if primary == true
				errors.add(:primary, "one primary insurable per policy") if policy.insurables.count >= 1 	
			end  
		end
end
