class PolicyGroupPremium < ApplicationRecord
  belongs_to :policy_group_quote
  belongs_to :billing_strategy
  belongs_to :commission_strategy, optional: true

  has_many :policy_premiums, through: :policy_group_quote

  def calculate_total
    keys = %i[
      base taxes total_fees total
      calculation_base deposit_fees amortized_fees
      carrier_base special_premium unearned_premium
    ]
    values = policy_premiums.pluck(keys).transpose.map(&:sum)
    self.attributes = Hash[keys.zip values]
    save
  end
end
