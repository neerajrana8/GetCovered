##
# =Fee Model
# file: +app/models/fee.rb+

class Fee < ApplicationRecord
  include SetSlug
  
  # Turn off single table inheritance
  self.inheritance_column = :_type_disabled
  
  belongs_to :assignable, polymorphic: true
  belongs_to :ownerable, polymorphic: true # Can be either Agency or Carrier
  
  validate :prevent_amortize_of_per_payment_fees
  
  enum type: { ORIGINATION: 0, RENEWAL: 1, REINSTATEMENT: 2, MISC: 3 }
  enum amount_type: { FLAT: 0, PERCENTAGE: 1 }
  
  def calc_total(payment_count = nil, premium_amount = nil)
		base = amount_type == 'FLAT' ? amount : premium_amount / (amount.to_f / 100)
		
		if per_payment?
			base = base * payment_count
		end

		return base
  end
  
  private
    
    def prevent_amortize_of_per_payment_fees
      errors.add(:amortize, "cannot be selected for a fee charged on every payment") if per_payment? && amortize? 
    end
end
