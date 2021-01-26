##
# =Policy Premium Model
# file: +app/models/policy_premium.rb+

class PolicyPremium < ApplicationRecord
  belongs_to :policy, optional: true
  belongs_to :policy_quote, optional: true
	belongs_to :billing_strategy, optional: true
	belongs_to :commission_strategy, optional: true
	
	has_one :commission
	
  has_many :policy_premium_fees
  has_many :fees, 
    through: :policy_premium_fees
  has_many :policy_premium_items
  
  validate :correct_total
  
  after_create :update_unearned_premium

  def application
		return policy_quote.policy_application  
  end
  
  def reset_premium
	  
	  logger.debug "\n\nRESETING PREMIUM\n\n".green
	  
		update amortized_fees: 0,
					 deposit_fees: 0,
					 calculation_base: 0,
					 total_fees: 0,
					 total: 0

		calculate_fees(true)
		calculate_total(true)			  
	end
  
  def correct_total
		errors.add(:total, 'incorrect total') if total != combined_premium() + taxes + total_fees
		errors.add(:calculation_base, 'incorrect calculation base') if calculation_base != combined_premium(internal: true) + internal_taxes + amortized_fees
  end
  
  def combined_premium(internal: nil)
    return include_special_premium ? self.internal_base + self.internal_special_premium : self.internal_base if internal
		return include_special_premium ? self.base + self.special_premium : self.base  
	end
  
  def set_fees
	  # Get CarrierPolicyTypeAvailability Fee for Region
	  # Assumption is made if the policy has gotten this far
	  # It is in an available region
	  carrier_policy_type = application().carrier
	  																	 .carrier_policy_types
	  																	 .where(:policy_type => policy_quote.policy_application.policy_type)
	  																	 .take
	  
	  state = application().insurables.empty? ? application().fields["premise"][0]["address"]["state"] : 
	                                            application().primary_insurable().primary_address().state
	  
	  regional_availability = CarrierPolicyTypeAvailability.where(
		  :state => state,
		  :carrier_policy_type => carrier_policy_type
	  ).take
		
		found_fees = regional_availability.fees + billing_strategy.fees
		found_fees.each { |fee| self.fees << fee }
    
    # add items for fees
		payments_count = billing_strategy.new_business["payments"].count{|x| x > 0 }
    found_fees.each do |fee|
      payments_total = case fee.amount_type
        when "FLAT";        fee.amount * (fee.per_payment ? payments_count : 1)
        when "PERCENTAGE";  ((fee.amount.to_d / 100) * self.combined_premium).ceil * (fee.per_payment ? payments_count : 1)
        # MOOSE WARNING: is .ceil acceptable in the line above?
      end
      self.policy_premium_items << PolicyPremiumItem.new(
        recipient: ###MOOSE WARNING FILL OUT #####,
        source: fee,
        title: fee.title || "#{(fee.amortized || fee.per_payment) ? "Amortized " : ""} Fee",
        category: "fee",
        amortized: fee.amortized || fee.per_payment,
        external: false, # MOOSE WARNING: when should this be true?
        preprocessed: false, # MOOSE WARNING: when should this be true?
        original_total_due: payments_total,
        total_due: payments_total,
        total_received: 0,
        total_processed: 0
      )
      # MOOSE WARNING: do we need a validation in this method to avoid re-creating items if it's called twice?
      # MOOSE WARNING: add to self.amortized_fees or self.deposit_fees appropriately
    end
		
	end
	
	def calculate_fees(persist = false)
    self.amortized_fees = self.policy_premium_items.where(category: "fee", amortized: true, external: false)
                                                   .inject(0){|sum,item| sum + item.total_due }
    self.deposit_fees = self.policy_premium_items.where(category: "fee", amortized: false, external: false)
                                                   .inject(0){|sum,item| sum + item.total_due }
    self.external_fees = self.policy_premium_items.where(category: "fee", external: true)
                                                   .inject(0){|sum,item| sum + item.total_due }
	  self.total_fees = self.amortized_fees + self.deposit_fees + self.external_fees
    save() if persist
  end
  
  def calculate_total(persist = false)
    self.total = self.combined_premium() + self.taxes + self.total_fees
    self.carrier_base = self.combined_premium() + self.taxes
    self.calculation_base = self.combined_premium(internal: true) + self.internal_taxes + self.amortized_fees
    save() if self.total > 0 && persist
  end
  
  def update_unearned_premium
    new_unearned_premium = -self.internal_base +
      ::LineItem.all.references(:invoices).includes(:invoice)
        .where(category: 'base_premium', invoices: { invoiceable_type: 'PolicyQuote', invoiceable_id: self.policy_quote_id })
        .inject(0){|sum,li| sum + li.collected }
    # these validations shouldn't be ever necessary, but let's be safe!
    new_unearned_premium =  new_unearned_premium > 0 ? 0 :
                            new_unearned_premium < -self.internal_base ? -self.internal_base :
                            new_unearned_premium
    self.update(unearned_premium: new_unearned_premium)
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
