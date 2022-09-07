# == Schema Information
#
# Table name: policy_premium_item_payment_terms
#
#  id                             :bigint           not null, primary key
#  weight                         :integer          not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  policy_premium_payment_term_id :bigint
#  policy_premium_item_id         :bigint
#
class PolicyPremiumItemPaymentTerm < ApplicationRecord

  # Associations
  belongs_to :policy_premium_payment_term
  belongs_to :policy_premium_item
  
  has_one :line_item,
    as: :chargeable

  def original_first_moment
    self.policy_premium_payment_term.original_first_moment
  end
  
  def original_last_moment
    self.policy_premium_payment_term.original_last_moment
  end
    
  def <=>(other)
    tr = (self.original_first_moment <=> other.original_first_moment)
    return tr == 0 ? self.original_last_moment <=> other.original_last_moment : tr
  end
end
