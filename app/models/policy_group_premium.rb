# == Schema Information
#
# Table name: policy_group_premia
#
#  id                      :bigint           not null, primary key
#  base                    :integer          default(0)
#  taxes                   :integer          default(0)
#  total_fees              :integer          default(0)
#  total                   :integer          default(0)
#  estimate                :integer
#  calculation_base        :integer          default(0)
#  deposit_fees            :integer          default(0)
#  amortized_fees          :integer          default(0)
#  special_premium         :integer          default(0)
#  integer                 :integer          default(0)
#  include_special_premium :boolean          default(FALSE)
#  boolean                 :boolean          default(FALSE)
#  carrier_base            :integer          default(0)
#  unearned_premium        :integer          default(0)
#  enabled                 :boolean          default(FALSE), not null
#  enabled_changed         :datetime
#  policy_group_quote_id   :bigint
#  billing_strategy_id     :bigint
#  commission_strategy_id  :bigint
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  policy_group_id         :bigint
#  only_fees_internal      :boolean          default(FALSE)
#  external_fees           :integer          default(0)
#
class PolicyGroupPremium < ApplicationRecord
  belongs_to :policy_group_quote
  belongs_to :billing_strategy
  belongs_to :commission_strategy, optional: true
  belongs_to :policy_group, optional: true

  has_many :policy_premiums, through: :policy_group_quote

  def calculate_total
    keys = %i[
      base taxes total_fees total
      calculation_base deposit_fees amortized_fees external_fees
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
