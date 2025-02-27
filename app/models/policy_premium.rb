# == Schema Information
#
# Table name: policy_premia
#
#  id                         :bigint           not null, primary key
#  total_premium              :integer          default(0), not null
#  total_fee                  :integer          default(0), not null
#  total_tax                  :integer          default(0), not null
#  total                      :integer          default(0), not null
#  prorated                   :boolean          default(FALSE), not null
#  prorated_last_moment       :datetime
#  prorated_first_moment      :datetime
#  force_no_refunds           :boolean          default(FALSE), not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  error_info                 :string
#  policy_quote_id            :bigint
#  policy_id                  :bigint
#  commission_strategy_id     :bigint
#  archived_policy_premium_id :bigint
#  total_hidden_fee           :integer          default(0), not null
#  total_hidden_tax           :integer          default(0), not null
#
##
# =Policy Premium Model
# file: +app/models/policy_premium.rb+

class PolicyPremium < ApplicationRecord
  
  # Associations
  belongs_to :policy_quote, optional: true
  belongs_to :policy, optional: true
  belongs_to :commission_strategy

  has_many :policy_premium_payment_terms
  has_many :policy_premium_items
  has_many :policy_premium_item_commissions,
    through: :policy_premium_items
  
  has_one :policy_application,
    through: :policy_quote
  has_one :billing_strategy,
    through: :policy_application
  has_many :fees,
    as: :assignable
  def carrier_agency_policy_type; @capt ||= ::CarrierAgencyPolicyType.where(policy_type_id: self.policy_rep.policy_type_id, carrier_agency_id: self.policy_rep.carrier_agency.id).take; end
  has_many :commission_items,
    through: :policy_premium_item_commissions

  # Callbacks
  before_validation :set_default_commission_strategy,
    on: :create,
    if: Proc.new{|pp| pp.commission_strategy.nil? && !pp.policy_rep.nil? }
    
  # validations
  validate :has_policy_or_policy_quote
  
  # Public Class Methods
  def self.default_collector
    @default_collector ||= ::Agency.where(master_agency: true).take
  end

  # Public Instance Methods
  def total_fees
    self.total_fee
  end
  
  def update_totals(persist: true)
    new_total = 0
    fee_hidden_total = 0
    tax_hidden_total = 0
    self.policy_premium_items.group_by{|ppi| ppi.category }
                             .select do |k,v|
                                fee_hidden_total = v.select{|ppi| ppi.hidden }.inject(0){|sum,ppi| sum + ppi.original_total_due } if k == 'fee'
                                tax_hidden_total = v.select{|ppi| ppi.hidden }.inject(0){|sum,ppi| sum + ppi.original_total_due } if k == 'tax'
                                ['premium', 'fee', 'tax'].include?(k)
                             end
                             .transform_values{|v| v.inject(0){|sum,ppi| sum + ppi.original_total_due } }
                             .each do |category, quantity|
      self.send("total_#{category}=", quantity)
      new_total += quantity
    end
    self.total_hidden_fee = fee_hidden_total
    self.total_hidden_tax = tax_hidden_total
    self.total = new_total
    persist ? self.save : true
  end
  
  def initialize_all(premium_amount, billing_strategy_terms: nil, start_date: nil, last_date: nil, tax: nil, taxes: nil, term_group: nil, collector: nil, filter_fees: nil, tax_recipient: nil, first_payment_down_payment: false, first_payment_down_payment_override: nil, first_tax_payment_down_payment_override: nil)
    tax = taxes if tax.nil? && !taxes.nil?
    return "Tax must be >= 0" if tax && tax < 0
    return "Tax recipient must be specified" unless !tax || tax == 0 || !tax_recipient.nil?
    return "PolicyPremium must be persisted to the database before initializing" unless self.id
    result = nil
    ActiveRecord::Base.transaction do
      result = self.create_payment_terms(term_group: term_group, start_date: start_date, last_date: last_date, billing_strategy_terms: billing_strategy_terms)
      raise ActiveRecord::Rollback unless result.nil? || result.end_with?("already exist")
      # premium
      result = self.itemize_premium(premium_amount, and_update_totals: false, term_group: term_group, collector: collector, first_payment_down_payment: first_payment_down_payment, first_payment_down_payment_override: first_payment_down_payment_override)
      raise ActiveRecord::Rollback unless result.nil?
      # taxes
      unless tax.nil? || tax == 0
        result = self.itemize_taxes(tax, and_update_totals: false, term_group: term_group, collector: collector, recipient: tax_recipient, first_payment_down_payment: first_payment_down_payment, first_payment_down_payment_override: first_tax_payment_down_payment_override)
        raise ActiveRecord::Rollback unless result.nil?
      end
      # fees
      result = self.itemize_fees(premium_amount, and_update_totals: false, term_group: term_group, collector: collector, filter: filter_fees)
      raise ActiveRecord::Rollback unless result.nil?
      # oop-dayte
      self.update_totals(persist: true)
    end
    return result
  end
  
  def add_premium_item(
    premium_amount,
    start_date,
    title: nil,                               # use to override default line item title of "Premium"
    and_modify_invoices: true,                # pass false to skip invoice generation
    use_later_invoice_if_needed: true,        # if the provided start_date means some charges should have been collected in the past, true will frontload them on the first available invoice; false will return failure
    term_group: nil,                          # pass a string to customize the term group of generated invoices
    collector: nil                            # can be overridden if GetCovered isn't the one actually collecting payment
  )
    term_group ||= "tg_#{premium_amount}_#{start_date.to_s}_#{Time.current.to_i}_#{rand(2**32)}"
    result = nil
    ActiveRecord::Base.transaction do
      result = self.create_payment_terms(
        term_group: term_group,
        start_date: start_date,
        alignment_start: self.policy_rep.effective_date,
      )
      raise ActiveRecord::Rollback unless result.nil? || result.end_with?("already_exist")
      # premium
      metadata = {}
      result = self.itemize_premium(premium_amount, title: title, and_update_totals: false, metadata: metadata, term_group: term_group, collector: collector)
      raise ActiveRecord::Rollback unless result.nil?
      # invoices
      if and_modify_invoices
        if self.policy_quote.nil?
          result = "Cannot modify invoices because PolicyQuote does not yet exist"
          raise ActiveRecord::Rollback
        end
        # generate line items
        ppi = metadata[:down_payment] || metadata[:amortized_premium] # only one will exist since we didn't request first_payment_down_payment mode
        line_items = ppi.generate_line_items(term_group: term_group)
        if line_items.class == ::String
          result = "Unable to generate line items: #{line_items}"
          raise ActiveRecord::Rollback
        end
        # add line items to invoices MOOSE WARNING: ideally we would lock ourselves and the invoices here, but there's a specific order of model locking that needs to be looked up somewhere in the documentation to be sure it's followed so that deadlocks remain impossible before that's implemented
        line_items.each do |line_item|
          # find the invoice
          invoice = self.policy_quote.invoices.where(status: ['available', 'upcoming']).where("due_date <= ?", line_item.chargeable.policy_premium_payment_term.first_moment.to_date).order("due_date desc").first
          if invoice.nil?
            if !use_later_invoice_if_needed
              result = "There is no available or upcoming invoice with due_date less than or equal to the policy premium item term start date (#{line_item.chargeable.policy_premium_payment_term.first_moment.to_date})"
              raise ActiveRecord::Rollback
            else
              invoice = self.policy_quote.invoices.where(status: ['available', 'upcoming']).order("due_date asc").first
              if invoice.nil?
                result = "The policy quote has no available or upcoming invoices, so line items could not be added"
                raise ActiveRecord::Rollback
              end
            end
          end
          # add the line item
          invoice.line_items.push(line_item)
          invoice.send(:mark_line_items_priced_in) # private method normally called within on_create callback
          invoice.save!
        end
      end
      # update totals to reflect the new fella
      self.update_totals(persist: true)
    end
    return result
  end 


  def create_payment_terms(
    term_group: nil,                  # an optional string to group payment terms for the same premium
    billing_strategy_terms: nil,      # array of up to 12 integer weights describing distribution of payments over monthly terms; defaults to the policy's billing strategy's new_business array 
    start_date: nil,                  # the first day of the first payment term; defaults to the policy's effective_date
    alignment_start: nil,             # the first day of the first payment term for month alignment purposes; billing strategy term weights apply to months starting from this date; defaults to start_date
    last_date: nil,                   # the last day of the last payment term; defaults to expiration_date
    adjust_first_weight: true,        # true if the first weight represents the weight that term WOULD have for a full month, and we should adjust it if start_date isn't an exact number of months after alignment_start
    sum_preterm_weights: false        # if alignment_start is months before start_date, by default we behave as if billing_strategy_terms had 0 entries for the months fully before start_date; true here makes us instead sum up any nonzero terms in this interim and dump the weight on the first payment. In other words, default behavior is "keep to the applicable part of the provided proportionate payment schedule" whereas passing true here is for "you're entering in the middle of the schedule and owe the money that WOULD have been due before you entered in up front"
  )
    # figure out basic shizzle
    billing_strategy_terms ||= self.policy_application&.billing_strategy&.new_business&.[]('payments')
    start_date ||= self.policy_rep.effective_date
    alignment_start ||= start_date
    if alignment_start > start_date
      start_date = alignment_start # we have implicit 0 weights for the terms before alignment_start, since billing_strategy_terms are monthly starting on alignment_start; so this setup is equivalent
    end
    while alignment_start <= start_date - 1.month
      alignment_start += 1.month
      billing_strategy_terms.shift
      billing_strategy_terms.first += billing_strategy_terms.shift if sum_preterm_weights && billing_strategy_terms.length > 1
    end
    billing_strategy_terms = [1] if billing_strategy_terms.blank?
    last_date ||= self.policy_rep.expiration_date
    # flee if arguments are invalid
    return "No billing_strategy_terms were provided and policy application does not exist or has no associated billing strategy" if billing_strategy_terms.blank?
    return "Payment terms for term group '#{term_group || 'nil'}' already exist" unless self.policy_premium_payment_terms.where(term_group: term_group).blank?
    return "The billing strategy terms are interpreted as applying to successive months, but there are more than 12 of them" if billing_strategy_terms.length > 12
    # prepare useful values
    returned_errors = nil
    term_start = start_date
    next_term_start = alignment_start + 1.month
    term_weight = billing_strategy_terms.first
    term_weight_multiplier = if alignment_start == start_date || !adjust_first_weight
        1
      else
        nil # will be the number of days the first term WOULD have if start_date were aligned, but we can't set it until we know when the first term ends
    end
    next_weight = 0
    ActiveRecord::Base.transaction do
      begin
        (1..billing_strategy_terms.length).each do |index|
          if index == billing_strategy_terms.length || (next_weight = billing_strategy_terms[index]) > 0
            # we have reached the end of a sequence of 0-weight months (which should get gobbled up all together by a single term)
            last_moment = (index == billing_strategy_terms.length || next_term_start > last_date ? last_date : next_term_start - 1.day).end_of_day
            multiplier = term_weight_multiplier
            if multiplier.nil?
              term_weight_multiplier = ((last_moment.to_date + 1.day) - alignment_start).to_i # number of days between alignment start and the end of the current (first) term
              multiplier = ((last_moment.to_date + 1.day) - term_start).to_i # number of days ACTUALLY in the term (due to non-alignment)
            end
            ::PolicyPremiumPaymentTerm.create!(
              policy_premium: self,
              term_group: term_group,
              first_moment: term_start.beginning_of_day,
              last_moment: last_moment,
              time_resolution: 'day',
              default_weight: term_weight * multiplier
            )
            term_start = next_term_start
            next_term_start = term_start + 1.month
            term_weight = next_weight
            break if last_moment.to_date == last_date
          else
            next_term_start += 1.month
          end
        end
      rescue ActiveRecord::RecordInvalid => rie
        # MOOSE WARNING: error! should we really just throw the hash back at the caller?
        returned_errors = rie.record.errors.to_h.to_s
        raise ActiveRecord::Rollback
      end
    end
    return returned_errors
  end
  
  
  def get_fees
	  # Get CarrierPolicyTypeAvailability Fee for Region (we assume region is available if we've gotten this far)
	  carrier_policy_type = self.policy_rep.carrier.carrier_policy_types.where(:policy_type => self.policy_rep.policy_type).take
    state = !self.policy_rep.insurables.empty? ?
      self.policy_rep.primary_insurable.primary_address.state
      : self.policy_application&.fields&.class == ::Hash ? self.policy_application.fields&.[]("premise")&.[](0)&.[]("address")&.[]("state")
      : nil # MOOSE WARNING what about pensio's hideous hack with no insurables :(?
    regional_availability = ::CarrierPolicyTypeAvailability.where(state: state, carrier_policy_type: carrier_policy_type).take
    return (carrier_policy_type&.fees || []) + (regional_availability&.fees || []) + (self.policy_application&.billing_strategy&.fees || []) + self.fees
  end
  
  def itemize_fees(percentage_basis, and_update_totals: true, term_group: nil, payment_terms: nil, collector: nil, filter: nil)
    # get payment terms
    payment_terms ||= self.policy_premium_payment_terms.where(term_group: term_group).sort.select{|p| p.default_weight != 0 }
    if payment_terms.blank?
      return "This PolicyPremium has no PolicyPremiumPaymentTerms with term_group = '#{term_group || 'nil'}'"
    elsif payment_terms.any?{|p| p.default_weight.nil? }
      return "This PolicyPremium has PolicyPremiumPaymentTerms with term_group = '#{term_group || 'nil'}' having default_weight equal to nil"
    end
    # get fees
    found_fees = self.get_fees
    already_itemized_fees = self.policy_premium_items.select(:fee_id).where(fee_id: found_fees.map{|ff| ff.id }).map{|ppi| ppi.fee }
    found_fees = found_fees - already_itemized_fees
    found_fees = found_fees.select{|ff| filter.call(ff) } unless filter.nil?
    # create fee items
    found_fees.each{|ff| result = self.itemize_fee(ff, percentage_basis, and_update_totals: false, payment_terms: payment_terms, collector: collector); return result unless result.nil? }
    self.update_totals(persist: true) if and_update_totals
    return nil
  end
  
  def itemize_fee(fee, percentage_basis, and_update_totals: true, term_group: nil, payment_terms: nil, collector: nil, recipient: nil)
    # get payment terms
    payment_terms = self.policy_premium_payment_terms.where(term_group: term_group).sort.select{|p| p.default_weight != 0 } if payment_terms.nil?
    if payment_terms.blank?
      return "This PolicyPremium has no PolicyPremiumPaymentTerms with term_group = '#{term_group || 'nil'}'"
    elsif payment_terms.any?{|p| p.default_weight.nil? }
      return "This PolicyPremium has PolicyPremiumPaymentTerms with term_group = '#{term_group || 'nil'}' having default_weight equal to nil"
    end
    # add item for fee
    payments_count = payment_terms.count
    payments_total = case fee.amount_type
      when "FLAT";        fee.amount.to_i * (fee.per_payment ? payments_count : 1)
      when "PERCENTAGE";  ((fee.amount.to_d / 100) * percentage_basis).ceil * (fee.per_payment ? payments_count : 1) # MOOSE WARNING: is .ceil acceptable?
    end
    created = ::PolicyPremiumItem.create(
      policy_premium: self,
      title: fee.title || "#{(fee.amortize || fee.per_payment) ? "Amortized " : ""} Fee",
      category: "fee",
      rounding_error_distribution: "first_payment_multipass",
      total_due: payments_total,
      proration_calculation: 'payment_term_exclusive',
      proration_refunds_allowed: false,
      hidden: fee.hidden,
      recipient: recipient || fee.ownerable,
      collector: collector || self.carrier_agency_policy_type&.collector || ::PolicyPremium.default_collector,
      policy_premium_item_payment_terms: (
        (fee.amortize || fee.per_payment) ? payment_terms.map.with_index do |pt, index|
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
    return "Failed to create PolicyPremiumItem for fee ##{fee.id} (#{fee.title})! Errors: #{created.errors.to_h}" unless created.id
    self.update_totals(persist: true) if and_update_totals
    return nil
  end
  
  def itemize_taxes(amount, recipient:, and_update_totals: true, proratable: nil, refundable: nil, term_group: nil, collector: nil, first_payment_down_payment: false, first_payment_down_payment_override: nil)
    self.itemize_premium(amount, and_update_totals: and_update_totals, proratable: proratable, refundable: refundable, term_group: term_group, collector: collector, is_tax: true, recipient: recipient, first_payment_down_payment: first_payment_down_payment, first_payment_down_payment_override: first_payment_down_payment_override)
  end

  def itemize_premium(amount, title: nil, and_update_totals: true, proratable: nil, refundable: nil, term_group: nil, payment_terms: nil, collector: nil, is_tax: false, recipient: nil, first_payment_down_payment: false, first_payment_down_payment_override: nil, metadata: nil) # pass a hash to metadata to get extra returned information
    title ||= (is_tax ? "Tax" : "Premium")
    # get payment terms
    payment_terms ||= self.policy_premium_payment_terms.where(term_group: term_group).sort.select{|p| p.default_weight != 0 }
    if payment_terms.blank?
      return "This PolicyPremium has no PolicyPremiumPaymentTerms"
    elsif payment_terms.any?{|p| p.default_weight.nil? }
      return "This PolicyPremium has PolicyPremiumPaymentTerms with default_weight equal to nil"
    end
    # clean up proratable & refundable
    cpt = nil
    if proratable.nil?
      proratable = (cpt ||= CarrierPolicyType.where(policy_type_id: self.policy_rep.policy_type_id, carrier_id: self.policy_rep.carrier_id).take)&.premium_proration_calculation
    elsif proratable == true
      proratable = 'per_payment_term' # MOOSE WARNING: default here?
    elsif proratable == false
      proratable = 'no_proration'
    elsif !::PolicyPremiumItem.proration_calculations.has_key?(proratable)
      return "Proration calculation method '#{proratable}' does not exist; you must pass 'proratable' as a valid value from PolicyPremiumItem::proration_calculation, pass true or false for the default options, or the appropriate CarrierPolicyType must exist and have a valid premium_proration_calculation value"
    end
    if refundable.nil?
      refundable = (cpt ||= CarrierPolicyType.where(policy_type_id: self.policy_rep.policy_type_id, carrier_id: self.policy_rep.carrier_id).take)&.premium_proration_refunds_allowed
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
      down_payment_amount = ((payment_terms.first.default_weight * amount) / total_weight).floor
      if first_payment_down_payment_amount_override && first_payment_down_payment_amount_override < down_payment_amount
        down_payment_revised_weight = (((down_payment_amount - first_payment_down_payment_amount_override.to_d) * payment_terms.first.default_weight) / down_payment_amount).floor
        down_payment_amount = first_payment_down_payment_amount_override
      else
        down_payment_revised_weight = 0
      end
      amount -= down_payment_amount
      unless down_payment_amount == 0 
        down_payment = ::PolicyPremiumItem.new(
          policy_premium: self,
          title: is_tax ? "#{title}" : "#{title} Down Payment",
          category: is_tax ? "tax" : "premium",
          rounding_error_distribution: "first_payment_simple",
          total_due: down_payment_amount,
          proration_calculation: 'no_proration',
          proration_refunds_allowed: false,
          recipient: recipient || self.commission_strategy,
          collector: collector || self.carrier_agency_policy_type&.collector || ::PolicyPremium.default_collector,
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
        policy_premium: self,
        title: is_tax ? "#{title}" : "#{title}",
        category: is_tax ? "tax" : "premium",
        rounding_error_distribution: "first_payment_multipass",
        total_due: amount,
        proration_calculation: proratable,
        proration_refunds_allowed: refundable,
        recipient: recipient || self.commission_strategy,
        collector: collector || self.carrier_agency_policy_type&.collector || ::PolicyPremium.default_collector,
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
    if metadata.class == ::Hash
      metadata.merge!({ down_payment: down_payment, amortized_premium: amortized_premium }.compact)
    end
    return save_error
  end

  def prorate(new_first_moment: nil, new_last_moment: nil, force_no_refunds: false)
    return nil if new_first_moment.nil? && new_last_moment.nil?
    # handle issues with the provided proration moments being less restrictive than exiting protations
    if new_first_moment && new_first_moment < (self.prorated_first_moment || self.policy_rep.effective_moment)
      if new_last_moment && new_last_moment <= (self.prorated_last_moment || self.policy_rep.expiration_moment)
        new_first_moment = nil # since NFM is less restrictive than a previously applied proration, just apply the NLM part
      else
        new_first_moment = (self.prorated_first_moment || self.policy_rep.effective_moment)
        #return "The requested new_first_moment #{new_first_moment.to_s} is invalid; it cannot precede the original or current prorated beginning of term (#{(self.prorated_first_moment || self.policy_rep.effective_moment).to_s})"
      end
    end
    if new_last_moment && new_last_moment > (self.prorated_last_moment || self.policy_rep.expiration_moment)
      if new_first_moment && new_first_moment >= (self.prorated_first_moment || self.policy_rep.effective_moment)
        new_last_moment = nil
      else
        new_last_moment = (self.prorated_last_moment || self.policy_rep.expiration_moment)
        #return "The requested new_last_moment #{new_last_moment.to_s} is invalid; it cannot be after the original or current prorated end of term (#{(self.prorated_last_moment || self.policy_rep.expiration_moment).to_s})"
      end
    end
    to_return = nil
    ActiveRecord::Base.transaction(requires_new: true) do
      # record the proration
      pfm = new_first_moment || self.prorated_first_moment || self.policy_rep.effective_moment
      plm = new_last_moment || self.prorated_last_moment || self.policy_rep.expiration_moment
      plm = pfm if plm < pfm
      unless self.update(
        prorated_first_moment: pfm,
        prorated_last_moment: plm,
        prorated: true,
        force_no_refunds: force_no_refunds
      )
        to_return = "The update to apply the proration failed, errors: #{self.errors.to_h}"
        raise ActiveRecord::Rollback
      end
      # prorate our terms
      self.policy_premium_payment_terms.order(id: :asc).lock.each do |pppt|
        unless pppt.update_proration(self.prorated_first_moment, self.prorated_last_moment)
          to_return = "Applying proration to PolicyPremiumPaymentTerm ##{pppt.id} failed, errors: #{pppt.respond_to?(:errors) ? pppt.errors.to_h : "(return value did not respond to errors call; type '#{pppt.class.name}')"}"
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
  
  def policy_rep
    @policy_rep ||= (self.policy_application || self.policy) # we try PA first because policy's effective/expiration dates/moments might be more expansive
  end
  
  private
  
    def set_default_commission_strategy
      prep = self.policy_application || self.policy # since this happens before validation and someone might still add a policy/policy quote without reloading the record, let's avoid using self.policy_rep
      self.commission_strategy = ::CarrierAgencyPolicyType.references(:carrier_agencies).includes(:carrier_agency)
                                                          .where(
                                                            policy_type_id: prep.policy_type_id,
                                                            carrier_agencies: {
                                                              carrier_id: prep.carrier_id,
                                                              agency_id: prep.agency_id
                                                            }
                                                          ).take&.commission_strategy
    end
  
    def has_policy_or_policy_quote
      errors.add(:base, "must be associated with a Policy or with a PolicyQuote with an associated PolicyApplication") if self.policy.nil? && self.policy_application.nil?
    end
  
end
