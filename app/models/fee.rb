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
  validate :amount_is_integral_when_flat
  
  enum type: { ORIGINATION: 0, RENEWAL: 1, REINSTATEMENT: 2, MISC: 3 }
  enum amount_type: { FLAT: 0, PERCENTAGE: 1 }
  
  def calc_total(payment_count = nil, premium_amount = nil)
		base = amount_type == 'FLAT' ? amount : premium_amount / (amount.to_f / 100)
		
		if per_payment?
			base = base * payment_count
		end

    base
  end
  
  private
    
  def prevent_amortize_of_per_payment_fees
    errors.add(:amortize, 'cannot be selected for a fee charged on every payment') if per_payment? && amortize? 
  end
    
  def ownerable_and_assignable_match_up
    case [assignable_type, ownerable_type]
    when %w[CarrierPolicyTypeAvailability Carrier]
      errors.add(:assignable, 'must belong to the same carrier') unless assignable.carrier_policy_type&.carrier_id == ownerable_id
    when %w[CarrierAgencyAuthorization Agency]
      errors.add(:assignable, 'must belong to the same agency') unless assignable.carrier_agency.agency_id == ownerable_id
    when %w[BillingStrategy Agency]
      errors.add(:assignable, 'must belong to the same agency') unless assignable.agency_id == ownerable_id
    else
      # WARNING: do nothing for now, but maybe throw an error for an invalid type selection if sure no other combinations are allowed
      # NOTE: fees now can have assignable_type PolicyPremium and ownerable_type Carrier/Agency/CommissionStrategy (i.e. the recipient of the fee);
      #       but there is little point to this validation, so I haven't changed it...
    end
  end
  
  def amount_is_integral_when_flat
    if self.amount_type == "FLAT" && self.amount && self.amount.floor != self.amount
      errors.add(:amount, 'must be an integer number of cents when amount_type is FLAT')
    end
  end
end
