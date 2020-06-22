class PolicyGroupPremium < ApplicationRecord
  belongs_to :policy_group_quote
  belongs_to :billing_strategy
  belongs_to :commission_strategy, optional: true
  belongs_to :policy_group, optional: true

  has_many :policy_premiums, through: :policy_group_quote

  def calculate_total
    keys = %i[
      base taxes total_fees total
      calculation_base deposit_fees amortized_fees
      external_fees only_fees_internal
      carrier_base special_premium unearned_premium
    ]
    values = policy_premiums.pluck(keys).transpose.map(&:sum)
    self.attributes = Hash[keys.zip values]
    save!
  end
  
  # internality methods
  
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
