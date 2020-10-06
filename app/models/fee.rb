##
# =Fee Model
# file: +app/models/fee.rb+

class Fee < ApplicationRecord
  include SetSlug
  
  # Turn off single table inheritance
  self.inheritance_column = :_type_disabled
  
  belongs_to :assignable, polymorphic: true
  belongs_to :ownerable, polymorphic: true # Can be either Agency or Carrier
  
  validates_presence_of :title, :slug, :type, :amount_type
  validates :amount,
    numericality: { greater_than_or_equal_to: 0 }
  validates_inclusion_of :amortize, :per_payment, :enabled, :locked,
    in: [true, false], message: 'cannot be blank'
  
  validate :prevent_amortize_of_per_payment_fees
  validate :ownerable_and_assignable_match_up
  
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
    
    def ownerable_and_assignable_match_up
      case [self.assignable_type, self.ownerable_type]
        when ['CarrierPolicyTypeAvailability', 'Carrier']
          errors.add(:assignable, "must belong to the same carrier") unless self.assignable.carrier_policy_type&.carrier_id == self.ownerable_id
        when ['CarrierAgencyAuthorization', 'Agency']
          errors.add(:assignable, "must belong to the same agency") unless self.assignable.carrier_agency.agency_id == self.ownerable_id
        when ['BillingStrategy', 'Agency']
          errors.add(:assignable, "must belong to the same agency") unless self.assignable.agency_id == self.ownerable_id
        else
          # WARNING: do nothing for now, but maybe throw an error for an invalid type selection if sure no other combinations are allowed
      end
    end
end
