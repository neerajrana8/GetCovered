# == Schema Information
#
# Table name: archived_policy_premia
#
#  id                      :bigint           not null, primary key
#  base                    :integer          default(0)
#  taxes                   :integer          default(0)
#  total_fees              :integer          default(0)
#  total                   :integer          default(0)
#  enabled                 :boolean          default(FALSE), not null
#  enabled_changed         :datetime
#  policy_quote_id         :bigint
#  policy_id               :bigint
#  billing_strategy_id     :bigint
#  commission_strategy_id  :bigint
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  estimate                :integer
#  calculation_base        :integer          default(0)
#  deposit_fees            :integer          default(0)
#  amortized_fees          :integer          default(0)
#  carrier_base            :integer          default(0)
#  special_premium         :integer          default(0)
#  include_special_premium :boolean          default(FALSE)
#  unearned_premium        :integer          default(0)
#  only_fees_internal      :boolean          default(FALSE)
#  external_fees           :integer          default(0)
#
class ArchivedPolicyPremium < ApplicationRecord
  belongs_to :policy, optional: true
  belongs_to :policy_quote, optional: true
	belongs_to :billing_strategy, optional: true
	belongs_to :commission_strategy, optional: true, class_name: "ArchivedCommissionStrategy", foreign_key: "commission_strategy_id"
	
	has_one :commission, class_name: "ArchivedCommission", foreign_key: "policy_premium_id"
	
  has_many :policy_premium_fees, class_name: "ArchivedPolicyPremiumFee", foreign_key: "policy_premium_id"
  has_many :fees, 
    through: :policy_premium_fees
    
  def combined_premium(internal: nil)
    return include_special_premium ? self.internal_base + self.internal_special_premium : self.internal_base if internal
		return include_special_premium ? self.base + self.special_premium : self.base  
	end
  
  def calculate_total(persist = false)
    self.total = self.combined_premium() + self.taxes + self.total_fees
    self.carrier_base = self.combined_premium() + self.taxes
    self.calculation_base = self.combined_premium(internal: true) + self.internal_taxes + self.amortized_fees
    save() if self.total > 0 && persist
  end
  
  def internal_fees
    self.amortized_fees + self.deposit_fees
  end
  
  def internal_base
    self.only_fees_internal ? 0 : self.base
  end
  
  def internal_special_premium
    self.only_fees_internal ? 0 : self.special_premium
  end
  
  def internal_taxes
    self.only_fees_internal ? 0 : self.taxes
  end
  
  def internal_total
    self.only_fees_internal ? self.internal_fees : self.total - self.external_fees
  end
  
  
end
