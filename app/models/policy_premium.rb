class PolicyPremium < ApplicationRecord
  before_save :set_enabled_updated_on,
  	if: Proc.new { |premium| premium.enabled_changed? }
  	
  belongs_to :policy, optional: true
  belongs_to :policy_quote, optional: true
  
  private
  	
  	def set_enabled_updated_on
	  	self.enabled_changed = Time.now	
		end
		
end
