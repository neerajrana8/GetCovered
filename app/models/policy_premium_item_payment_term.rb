class PolicyPremiumItemPaymentTerm < ApplicationRecord

  # Associations
  belongs_to :policy_premium_payment_term
  belongs_to :policy_premium_item
  
  has_one :line_item,
    as: :chargeable
    
    
  def self.prepare_clean_slate(terms)
    terms.update_all(original_total_due: 0)
  end
    
  def <=>(other)
    tr = self.original_first_moment <=> other.original_first_moment
    return tr == 0 ? self.original_last_moment <=> other.original_last_moment : tr
  end
end








