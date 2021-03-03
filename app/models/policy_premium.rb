##
# =Policy Premium Model
# file: +app/models/policy_premium.rb+

class PolicyPremium < ApplicationRecord
  
  # Associations
  belongs_to :policy_quote
  belongs_to :billing_strategy
  belongs_to :commission_strategy
  belongs_to :policy, optional: true

  has_one :policy_application,
    through: :policy_quote
  has_many :policy_premium_items
  has_many :fees,
    through: :policy_premium_items
  
  # Public Class Methods
  def self.default_collector
    @default_collector ||= ::Agency.where(master_agency: true).take
  end

  # Public Instance Methods
  def update_totals(persist: true)
    new_total = 0
    self.policy_premium_items.group_by{|ppi| ppi.category }
                             .select{|k,v| ['premium', 'fee', 'tax'].include?(k) }
                             .transform_values{|v| v.inject(0){|sum,ppi| sum + ppi.original_total_due } }
                             .each do |category, quantity|
      self.send("total_#{category}=", quantity)
      new_total += quantity
    end
    self.total = new_total
    self.save if persist
  end
  
  def initialize_all(premium_amount, term_group: nil)
    result = nil
    ActiveRecord::Base.transaction do
      result = self.create_payment_terms(term_group: term_group)
      raise ActiveRecord::Rollback unless result.nil? || result.end_with?("already exist")
      result = self.itemize_premium(premium_amount, and_update_totals: false, term_group: term_group)
      raise ActiveRecord::Rollback unless result.nil?
      result = self.itemize_fees(premium_amount, and_update_totals: false, term_group: term_group)
      raise ActiveRecord::Rollback unless result.nil?
      self.update_totals(persist: true)
    end
    return result
  end
  
  def create_payment_terms(term_group: nil)
    return "Payment terms for term group '#{term_group || 'nil'}' already exist" unless self.payment_terms.where(term_group: term_group).blank?
    returned_errors = nil
    last_end = self.policy_quote.effective_date - 1.day
    extra_months = 0
    ActiveRecord::Base.transaction do
      begin
        self.billing_strategy.new_business["payments"].each.with_index do |weight,index|
          unless weight > 0
            extra_months += 1
            next
          end
          ::PolicyPremiumPaymentTerm.create!(
            policy_premium: self,
            first_moment: (last_end + 1.day).beginning_of_day,
            last_moment: (last_end = (last_end + 1.day + (1 + extra_months).months - 1.day)).end_of_day,
            time_resolution: 'day',
            default_weight: weight,
            term_group: term_group
          )
        end
      rescue ActiveRecord::RecordInvalid => rie
        # MOOSE WARNING: error! should we really just throw the hash back at the caller?
        returned_errors = rie.record.errors.to_h
        raise ActiveRecord::Rollback
      end
    end
    return returned_errors
  end
  
  def get_fees
	  # Get CarrierPolicyTypeAvailability Fee for Region (we assume region is available if we've gotten this far)
	  carrier_policy_type = self.policy_application.carrier.carrier_policy_types.where(:policy_type => self.policy_application.policy_type).take
    state = self.policy_application.insurables.empty? ?
      self.policy_application.fields["premise"][0]["address"]["state"]
      : self.policy_application.primary_insurable.primary_address.state
    regional_availability = ::CarrierPolicyTypeAvailability.where(state: state, carrier_policy_type: carrier_policy_type).take
    return regional_availability.fees + billing_strategy.fees
  end
  
  def itemize_fees(percentage_basis, and_update_totals: true, term_group: nil, payment_terms: nil, collector: nil)
    # get payment terms
    payment_terms = self.payment_terms.where(term_group: term_group).sort.select{|p| p.default_weight != 0 } if payment_terms.nil?
    if payment_terms.blank?
      return "This PolicyPremium has no PolicyPremiumPaymentTerms with term_group = '#{term_group || 'nil'}'"
    elsif payment_terms.any?{|p| p.default_weight.nil? }
      return "This PolicyPremium has PolicyPremiumPaymentTerms with term_group = '#{term_group || 'nil'}' having default_weight equal to nil"
    end
    # get fees
    found_fees = self.get_fees
    already_itemized_fees = self.policy_premium_items.select(:fee).where(fee: found_fees).map{|ppi| ppi.fee }
    found_fees = found_fees - already_itemized_fees
    # create fee items
    found_fees.each{|ff| self.itemize_fee(ff, percentage_basis, and_update_totals: false, payment_terms: payment_terms, collector: collector) }
    self.update_totals(persist: true) if and_update_totals
  end
  
  def itemize_fee(fee, percentage_basis, and_update_totals: true, term_group: nil, payment_terms: nil, collector: nil)
    # get payment terms
    payment_terms = self.payment_terms.where(term_group: term_group).sort.select{|p| p.default_weight != 0 } if payment_terms.nil?
    if payment_terms.blank?
      return "This PolicyPremium has no PolicyPremiumPaymentTerms with term_group = '#{term_group || 'nil'}'"
    elsif payment_terms.any?{|p| p.default_weight.nil? }
      return "This PolicyPremium has PolicyPremiumPaymentTerms with term_group = '#{term_group || 'nil'}' having default_weight equal to nil"
    end
    # add item for fee
    payments_count = payment_terms.count
    payments_total = case fee.amount_type
      when "FLAT";        fee.amount * (fee.per_payment ? payments_count : 1)
      when "PERCENTAGE";  ((fee.amount.to_d / 100) * percentage_basis).ceil * (fee.per_payment ? payments_count : 1) # MOOSE WARNING: is .ceil acceptable?
    end
    self.policy_premium_items << ::PolicyPremiumItem.new(
      title: fee.title || "#{(fee.amortized || fee.per_payment) ? "Amortized " : ""} Fee",
      category: "fee",
      rounding_error_distribution: "first_payment_simple",
      total_due: payments_total,
      proration_calculation: 'payment_term_exclusive',
      proration_refunds_allowed: false,
      # MOOSE WARNING: preprocessed
      recipient: fee.ownerable,
      collector: collector || self.billing_strategy.collector || ::PolicyPremium.default_collector,
      policy_premium_item_payment_terms: (
        (fee.amortized || fee.per_payment) ? payment_terms.map.with_index do |pt, index|
          ::PolicyPremiumItemPaymentTerm.new(
            policy_premium_payment_term: pt,
            weight: fee.per_payment ? 1 : pt.default_weight
          )
        end
        : [::PolicyPremiumItemPaymentTerm.new(
          policy_premium_payment_term: payment_terms.first,
          weight: 1
        )]
      )
    )
    self.update_totals(persist: true) if and_update_totals
  end

  def itemize_premium(amount, and_update_totals: true, proratable: nil, refundable: nil, term_group: nil, collector: nil)
    # get payment terms
    payment_terms = self.payment_terms.where(term_group: term_group).sort.select{|p| p.default_weight != 0 }
    if payment_terms.blank?
      return "This PolicyPremium has no PolicyPremiumPaymentTerms"
    elsif payment_terms.any?{|p| p.default_weight.nil? }
      return "This PolicyPremium has PolicyPremiumPaymentTerms with default_weight equal to nil"
    end
    # clean up proratable & refundable
    cpt = nil
    if proratable.nil?
      proratable = (cpt ||= CarrierPolicyType.where(policy_type_id: self.policy_application.policy_type_id, carrier_id: self.policy_application.carrier_id).take)&.premium_proration_calculation
    elsif proratable == true
      proratable = 'per_payment_term' # MOOSE WARNING: default here?
    elsif proratable == false
      proratable = 'no_proration'
    elsif !::PolicyPremiumItem.proration_calculations.has_key?(proratable)
      return "Proration calculation method '#{proratable}' does not exist; you must pass 'proratable' as a valid value from PolicyPremiumItem::proration_calculation, pass true or false for the default options, or the appropriate CarrierPolicyType must exist and have a valid premium_proration_calculation value"
    end
    if refundable.nil?
      refundable = (cpt ||= CarrierPolicyType.where(policy_type_id: self.policy_application.policy_type_id, carrier_id: self.policy_application.carrier_id).take)&.premium_proration_refunds_allowed
    end
    if refundable != true && refundable != false
      return "Proration 'refundable' property was not set to a boolean value; you must pass one, or the appropriate CarrierPolicyType must exist and have a valid premium_proration_refunds_allowed value"
    end
    # make the item(s)
    down_payment = nil
    amortized_premium = nil
    down_payment_revised_weight = nil
    if first_payment_down_payment
      total_weight = payment_terms.inject(0){|sum,pt| sum + pt.default_weight }.to_d
      down_payment_amount = (payment_terms.first.default_weight * amount / total_weight).floor
      if self.first_payment_down_payment_amount_override && self.first_payment_down_payment_amount_override < down_payment_amount
        down_payment_revised_weight = ((down_payment_amount - self.first_payment_down_payment_amount_override.to_d) / down_payment_amount * payment_terms.first.default_weight).floor
        down_payment_amount = self.first_payment_down_payment_amount_override
      else
        down_payment_revised_weight = 0
      end
      amount -= down_payment_amount
      unless down_payment_amount == 0 
        down_payment = ::PolicyPremiumItem.new(
          title: "Premium Down Payment",
          category: "premium",
          rounding_error_distribution: "first_payment_simple",
          total_due: down_payment_amount,
          proration_calculation: 'no_proration',
          proration_refunds_allowed: false,
          # MOOSE WARNING: preprocessed
          recipient: self.commission_strategy,
          collector: collector || self.billing_strategy.collector || ::PolicyPremium.default_collector,
          policy_premium_item_payment_terms: [payment_terms.first].map do |pt|
            ::PolicyPremiumItemPaymentTerm.new(
              policy_premium_payment_term: pt,
              weight: 1
            )
          end
        )
      end
    end
    unless amount == 0
      amortized_premium = ::PolicyPremiumItem.new(
        title: "Premium",
        category: "premium",
        rounding_error_distribution: "last_payment_multipass", #MOOSE WARNING: change default???
        total_due: amount,
        proration_calculation: proratable,
        proration_refunds_allowed: refundable,
        # MOOSE WARNING: preprocessed
        recipient: self.commission_strategy,
        collector: collector || self.billing_strategy.collector || ::PolicyPremium.default_collector,
        policy_premium_item_payment_terms: payment_terms.map.with_index do |pt, index|
          next nil if index == 0 && down_payment_revised_weight == 0
          ::PolicyPremiumItemPaymentTerm.new(
            policy_premium_payment_term: pt,
            weight: !down_payment_revised_weight.nil? ? down_payment_revised_weight : pt.default_weight
          )
        end.compact
      )
    end
    # save the item(s)
    save_error = nil
    ActiveRecord::Base.transaction do
      step = 'down payment'
      begin
        down_payment.save! unless down_payment.nil?
        step = 'amortized premium'
        amortized_premium.save! unless amortized_premium.nil?
      rescue ActiveRecord::RecordInvalid => rie
        # MOOSE WARNING: error! should we really just throw the hash back at the caller?
        save_error = "Failed to create PolicyPremiumItem for #{step}; errors: #{rie.record.errors.to_h.to_s}"
        raise ActiveRecord::Rollback
      end
    end
    self.update_totals(persist: true) if save_error.nil? && and_update_totals
    # all done
    return save_error
  end

  def prorate(new_first_moment: nil, new_last_moment: nil)
    return nil if new_first_moment.nil? && new_last_moment.nil?
    if new_first_moment && new_first_moment < (self.prorated_first_moment || self.policy_quote.effective_moment)
      return "The requested new_first_moment #{new_first_moment.to_s} is invalid; it cannot precede the original or current prorated beginning of term (#{(self.prorated_first_moment || self.policy_quote.effective_moment).to_s})"
    end
    if new_last_moment && new_last_moment > (self.prorated_last_moment || self.policy_quote.expiration_moment)
      return "The requested new_last_moment #{new_last_moment.to_s} is invalid; it cannot be after the original or current prorated end of term (#{(self.prorated_last_moment || self.policy_quote.expiration_moment).to_s})"
    end
    o_return = nil
    ActiveRecord::Base.transaction(requires_new: true) do
      # record the proration
      unless self.update(
        prorated_first_moment: new_first_moment || self.prorated_first_moment,
        prorated_last_moment: new_last_moment || self.prorated_last_moment,
        prorated: true
      )
        to_return = "The update to apply the proration failed, errors: #{self.errors.to_h}"
        raise ActiveRecord::Rollback
      end
      # prorate our terms
      self.policy_premium_payment_terms.each do |pppt|
        unless pppt.update_proration(self.prorated_first_moment, self.prorated_last_moment)
          to_return = "Applying proration to PolicyPremiumPaymentTerm ##{pppt.id} failed, errors: #{pppt.respond_to?(:errors) ? pppt.errors.to_h : '(return value did not respond to errors call)'}"
          raise ActiveRecord::Rollback
        end
      end
      # tell our items to apply the proration to their line items
      ppi_array = self.policy_premium_items.order(id: :asc).lock.to_a
      self.policy_premium_items.update_all(proration_pending: true)
    end
    return to_return unless to_return.nil?
    self.policy_premium_items.each do |ppi|
      ppi.apply_proration
    end
    return nil
  end
  
  
  
  
  
end
