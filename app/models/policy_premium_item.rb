# == Schema Information
#
# Table name: policy_premium_items
#
#  id                              :bigint           not null, primary key
#  title                           :string           not null
#  category                        :integer          not null
#  rounding_error_distribution     :integer          default("last_payment_simple"), not null
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  original_total_due              :integer          not null
#  total_due                       :integer          not null
#  total_received                  :integer          default(0), not null
#  proration_pending               :boolean          default(FALSE), not null
#  proration_calculation           :integer          not null
#  proration_refunds_allowed       :boolean          not null
#  commission_calculation          :integer          default("as_received"), not null
#  commission_creation_delay_hours :integer
#  policy_premium_id               :bigint
#  recipient_type                  :string
#  recipient_id                    :bigint
#  collector_type                  :string
#  collector_id                    :bigint
#  collection_plan_type            :string
#  collection_plan_id              :bigint
#  fee_id                          :bigint
#  hidden                          :boolean          default(FALSE), not null
#
class PolicyPremiumItem < ApplicationRecord
  # Associations
  belongs_to :policy_premium  # the policy_premium to which this item applies
  belongs_to :recipient,      # who receives this money (generally a Carrier, Agent, or CommissionStrategy)
    polymorphic: true
  belongs_to :collector,      # which Carrier/Agent actually collects the money from users
    polymorphic: true
  belongs_to :collection_plan,# what an external collector will pay off on their own (either null (collector pays off nothing), a parent CommissionStrategy of recipient (collector pays off that CS and its parents), or an Agency/Carrier/whatever (collector pays off all commissions to that entity))
    polymorphic: true,
    optional: true
  belongs_to :fee,            # what Fee this item corresponds to, if any
    optional: true


  has_many :policy_premium_item_payment_terms,
    autosave: true # MOOSE WARNING: does this suffice?
  has_many :policy_premium_item_commissions
  has_many :policy_premium_item_transactions

  has_one :policy_quote,
    through: :policy_premium
  has_many :line_items,
    through: :policy_premium_item_payment_terms
  has_many :line_item_reductions,
    through: :line_items
  has_many :commission_items,
    through: :policy_premium_item_commissions
    

  # Callbacks
  before_validation :set_missing_total_data,
    on: :create,
    if: Proc.new{|ppi| ppi.original_total_due.nil? || ppi.total_due.nil? }
  after_create :setup_commissions

  # Validations
  validates_presence_of :title
  validates_presence_of :category
  validates_presence_of :rounding_error_distribution
  validates :commission_creation_delay_hours, numericality: { greater_than: 0 },
    if: Proc.new{|ppi| ppi.commission_calculation == 'group_by_transaction' }
  validates :original_total_due, numericality: { greater_than_or_equal_to: 0 }
  validates :total_due, numericality: { greater_than_or_equal_to: 0 }
  validates :total_received, numericality: { greater_than_or_equal_to: 0 }
  validates_presence_of :proration_calculation
  validates_inclusion_of :proration_refunds_allowed, in: [true, false]
  validate :hidden_false_unless_fee_or_tax
  
  # Enums etc.
  enum category: {
    fee: 0,
    premium: 1,
    tax: 2
  }, _prefix: true, _suffix: false
  enum rounding_error_distribution: {
    last_payment_simple: 0,       # distributes total by weight rounded down to the nearest cent; dumps remainder on last payment
    first_payment_simple: 1,      # same but dumps on the first payment
    last_payment_multipass: 2,    # distributes total by weight rounded down to the nearest cent; distributes remainder by weight and repeats, until a distribution loop distributes nothing; then dumps remainder on last payment
    first_payment_multipass: 3,   # same but dumps on the first payment
    dynamic_forward: 4,           # distributes by weight in one pass, but keeps track of the amount not yet distributed and distributes that over remaining payments by weight
    dynamic_reverse: 5            # same but last-payment to first-payment
  }, _prefix: true, _suffix: false
  enum proration_calculation: {   # prorations cancel future payments; if proration_refunds_allowed is true, they can also refund past payments
    no_proration: 0,              # cancel/refund no payments on policy cancellation
    per_payment_term: 1,          # cancel/refund individual payment terms in proportion to the amount of the term cancelled
    payment_term_exclusive: 2,    # cancel/refund every payment term falling completely after the new policy last date
    payment_term_inclusive: 3,    # cancel/refund every payment term any portion of which falls after the new policy last date
    #per_total: 4                 # NOT IMPLEMENTED FOR NOW SINCE NOT USED. cancel/refund everything in proportion to the amount of the total active policy duration cancelled (i.e. total cancelled amount will be unaffected by how payments were distributed over payment terms)
  }, _prefix: true, _suffix: false
  enum commission_calculation: {
    as_received: 0,               # whenever payments are received (or refunds given), generation a CommissionItem for the appropriate amount
    no_payments: 1,               # there will be no payments made on this PPI and hence no commissions; it is a dummy PPI that exists to track some bizarre nonsense (for instance the base premium PPI for master policies -___-)
    group_by_transaction: 2       # we will generate a commission item only when attempt_commission_update is called with a reason.reason different from the one used last call, or after commission_creation_delay_hours hours
  }, _prefix: true, _suffix: false
  
  # Public Class Methods
  
  # Public Instance Methods
  
  # WARNING: currently, this method does not create new line items under any circumstances; it only modifies existing ones
  def change_remaining_total_by(quantity, start_date = Time.current.to_date, treat_as_original: false, build_on_term_group: nil, first_term_prorated: true, term_group_name: "ppi#{self.id}crtb#{quantity}time#{Time.current.to_i}rand#{rand(9999999)}", clamp_start_date_to_effective_date: true, clamp_start_date_to_today: true, clamp_start_date_to_first: true)
    return "No line items exist on payable invoices, so there is no way to change their totals" if self.line_items.references(:invoices).includes(:invoice).where(invoices: { status: ['upcoming', 'available'] }).blank?
    error_message = nil
    ActiveRecord::Base.transaction(requires_new: true) do
      # lock our bois
      self.policy_premium.lock! if treat_as_original # MOOSE WARNING: should review finance system record locking order in the documentation, this might not should go here
      invoice_array = ::Invoice.where(id: self.line_items.map{|li| li.invoice_id }).order(id: :asc).lock.to_a
      line_item_array = self.line_items.order(id: :asc).lock.to_a
      self.lock!
      # alter totals
      if treat_as_original
        self.update(original_total_due: self.original_total_due + quantity)
        self.policy_premium.update_totals
      end
      # flee if nonsense
      if quantity < 0 && -quantity > total_due
        error_message = "PolicyPremiumItem total_due cannot be negative"
        raise ActiveRecord::Rollback
      end
      # clamp the start date
      if clamp_start_date_to_effective_date
        effledeet = (self.policy_quote&.policy || self.policy_quote&.policy_application)&.effective_date
        start_date = effldeet if effledeet&.>(start_date)
      end
      if clamp_start_date_to_today
        start_date = Time.current.to_date if start_date < Time.current.to_date 
      end
      # grab PPIPTs we're going to use
      ppipts = self.policy_premium_item_payment_terms.references(:policy_premium_payment_terms).includes(:policy_premium_payment_term)
               .where("policy_premium_payment_terms.last_moment >= ?", start_date)
               .where(policy_premium_payment_terms: { term_group: build_on_term_group, cancelled: false })
               .order("policy_premium_payment_terms.first_moment ASC, policy_premium_payment_terms.last_moment DESC")
               .to_a
      if ppipts.blank?
        error_message = "No policy premium item payment terms exist with last_moment >= the requested start_date (#{start_date.to_s})"
        raise ActiveRecord::Rollback
      end
      if ppipts.any?{|ppipt| ppipt.policy_premium_payment_term.time_resolution != 'day' }
        error_message = "Encountered a PolicyPremiumItemPaymentTerm whose time_resolution is not 'day'; PPI#change_remaining_total_by does not currently support such madness (id #{ppipts.find{|ppipt| ppipt.policy_premium_payment_term.time_resolution != 'day' }.id})"
        raise ActiveRecord::Rollback
      end
      if clamp_start_date_to_first && start_date < ppipts.first.policy_premium_payment_term.first_moment.to_date
        start_date = ppipts.first.policy_premium_payment_term.first_moment.to_date
      end
      # replace the PPIPTs as necessary
      new_ppipts = []
      multiplier = 1
      if ppipts.first.policy_premium_payment_term.first_moment.to_date == start_date
        new_ppipts.push(ppipts.first)
      else
        days_included = ((ppipts.first.policy_premium_payment_term.last_moment.to_date + 1.day) - (start_date)).to_i # number of days included in our derivative term
        multiplier = ((ppipts.first.policy_premium_payment_term.last_moment.to_date + 1.day) - (ppipts.first.policy_premium_payment_term.first_moment.to_date)).to_i # number of days actually in the term
        new_first_pppt = ppipts.first.policy_premium_payment_term.dup
        new_first_pppt.term_group = term_group_name
        new_first_pppt.first_moment += (start_date - new_first_pppt.first_moment.to_date).to_i.days # maybe a more convenient base to mod from when adding support one day for non-day time_resolution values?
        new_first_pppt.created_at = Time.current
        new_first_pppt.updated_at = new_first_pppt.created_at
        new_first_pppt.save
        if new_first_pppt.id.blank?
          error_message = "Failed to copy first PolicyPremiumPaymentTerm: #{new_first_pppt.errors.to_h}"
          raise ActiveRecord::Rollback
        end
        new_first = ::PolicyPremiumItemPaymentTerm.new(
          policy_premium_item: self,
          policy_premium_payment_term: new_first_pppt,
          weight: !first_term_prorated ? ppipts.first.weight : ppipts.first.weight * days_included # multiply by the number of days between the two
        )
        new_first.save
        if new_first.id.blank?
          error_message = "Failed to copy first PolicyPremiumItemPaymentTerm: #{new_first.errors.to_h}"
          raise ActiveRecord::Rollback
        end
        new_ppipts.push(new_first)
      end
      new_ppipts += ppipts.drop(1)
      # grab existing line items per ppipt, ignoring spent ones
      preexisting = ppipts.map do |ppipt|
        ['upcoming', 'available'].include?(ppipt.line_item&.invoice&.status) ? ppipt.line_item : nil
      end
      preexisting = preexisting.map.with_index do |li, ind| # ensure nil ones are set to the next available invoice, or the prev if not exists, or abort process if none
        next li unless li.nil?
        found = preexisting[ ((ind+1)...(preexisting.length)).find{|i| !preexisting[i].nil? } ] ||
                      preexisting[ (0...(ind-1)).to_a.reverse.find{|i| !preexisting[i].nil? } ]
        if found.nil?
          error_message = "No line items exist on available or upcoming invoices; unable to modify line items"
          raise ActiveRecord::Rollback
        end
        next found
      end
      # generate unsaved new line items
      lis = generate_line_items(force: true, override_original_total_due: quantity.abs, override_ppipts: new_ppipts)
      # use unsaved new line items to modify existing line items
      lis.each.with_index do |li|
        # get da fella ta change
        index = new_ppipts.find_index{|ppipt| ppipt == li.chargeable }
        if index.nil?
          error_message = "Theoretically impossible error encountered: generated line item's PPIPT does not exist in the PPIPT list! Seek out a wise owl to fix the bug."
          raise ActiveRecord::Rollback
        end
        to_change = preexisting[index]
        if to_change.nil?
          error_message = "Theoretically impossible error encountered: a nil entry exists in the preexisting PPIPT list! Find a clever fox to repair the code."
          raise ActiveRecord::Rollback
        end
        # make dat change bro
        LineItemReduction.create!(
          line_item: to_change,
          reason: self, # MOOSE WARNING: this provides no useful information, lol, but I'm not sure what else to put here
          refundability: 'cancel_or_refund',
          amount_interpretation: quantity < 0 ? 'max_amount_to_reduce' : 'min_amount_to_reduce',
          amount: quantity < 0 ? li.total_due : -li.total_due,
          proration_interaction: 'reduced'
        )
      end
    end
    return error_message
  end

  def generate_line_items(term_group: nil, force: false, override_original_total_due: self.original_total_due, override_ppipts: nil, allow_preexisting: force, allow_no_payment: force)
    return "Line items are not permitted since this PolicyPremiumItem's commission calculation is set to no_payments" if self.commission_calculation == 'no_payments' && !allow_no_payment
    # verify we haven't already done this & clean our PolicyPremiumItemPaymentTerms
    return "Line items already scheduled" unless allow_preexisting || self.line_items.blank?
    to_return = (override_ppipts ||
      self.policy_premium_item_payment_terms.references(:policy_premium_payment_terms).includes(:policy_premium_payment_term)
      .where(policy_premium_payment_terms: { term_group: term_group })
      .order("policy_premium_payment_terms.first_moment ASC, policy_premium_payment_terms.last_moment DESC")
    ).map do |pt|
      ::LineItem.new(chargeable: pt, title: self.title, hidden: self.hidden, original_total_due: 0, analytics_category: "policy_#{self.category}", policy_quote: self.policy_quote)
    end
    return "There are no policy premium payment terms belonging to term group #{term_group ? "'#{term_group}'" : "<null>"}" if to_return.blank? 
    # calculate line item totals
    case self.rounding_error_distribution
      when 'dynamic_forward', 'dynamic_reverse'
        total_left = override_original_total_due
        weight_left = to_return.inject(0){|sum,li| sum + li.chargeable.weight }.to_d
        reversal = (self.rounding_error_distribution == 'dynamic_reverse' ? :reverse : :itself)
        to_return = to_return.send(reversal)
        to_return.each do |li|
          li.original_total_due = ((li.chargeable.weight * total_left) / weight_left).floor
          total_left -= li.original_total_due
          weight_left -= li.chargeable.weight
        end
      when 'first_payment_simple', 'last_payment_simple', 'first_payment_multipass', 'last_payment_multipass'
        total_weight = to_return.inject(0){|sum,li| sum + li.chargeable.weight }.to_d
        multiple_passes = self.rounding_error_distribution.end_with?("multipass")
        to_distribute = override_original_total_due
        loop do
          distributed = 0
          to_return.each do |li|
            li_total = ((li.chargeable.weight * to_distribute) / total_weight).floor
            li.original_total_due += li_total
            distributed += li_total
          end
          to_distribute -= distributed
          break if distributed == 0 || !multiple_passes
        end
        reversal = (self.rounding_error_distribution.start_with?('first_payment') ? :each : :reverse_each)
        (to_return.send(reversal).find{|li| li.original_total_due > 0 } || to_return.send(reversal).first).original_total_due += to_distribute unless to_distribute == 0
    end
    # return unsaved line items
    to_return.each{|li| li.preproration_total_due = li.original_total_due; li.total_due = li.original_total_due }
    return to_return.select{|tr| tr.total_due > 0 }
  end
  
  def apply_proration
    return nil unless self.proration_pending && self.policy_premium.prorated
    refunds_allowed = self.policy_premium.force_no_refunds ? false : self.proration_refunds_allowed
    error_message = nil
    ActiveRecord::Base.transaction(requires_new: true) do
      # lock our bois
      invoice_array = ::Invoice.where(id: self.line_items.map{|li| li.invoice_id }).order(id: :asc).lock.to_a
      line_item_array = self.line_items.order(id: :asc).lock.to_a
      self.lock!
      # flee if there's an issue (yes, we check proration_pending again, since we're in the lock now)
      return nil unless self.proration_pending && self.line_item_reductions.where(pending: true, proration_interaction: 'reduced').count == 0
      # apply the proration
      case self.proration_calculation
        when 'no_proration'
          # woohoo, we're done!
        # NOT IMPLEMENTED FOR NOW SINCE NOT USED. when 'per_total'
        when 'per_payment_term'
          terms = self.policy_premium_item_payment_terms.references(:policy_premium_payment_terms).includes(:policy_premium_payment_term)
                                                        .references(:line_items).includes(:line_item)
                                                        .where(policy_premium_payment_terms: { prorated: true })
          terms.each do |ppipt|
            next if ppipt.line_item.nil?
            created = ppipt.line_item.line_item_reductions.create(
              reason: "Proration Adjustment",
              amount_interpretation: 'max_total_after_reduction',
              amount: (ppipt.policy_premium_payment_term.unprorated_proportion * ppipt.line_item.preproration_total_due).ceil,
              refundability: refunds_allowed ? 'cancel_or_refund' : 'cancel_only',
              proration_interaction: 'is_proration'
            )
            unless created.id
              error_message = "Failed to create LineItemReduction for LineItem ##{ppipt.line_item_id}; errors: #{created.errors.to_h}"
              raise ActiveRecord::Rollback
            end
          end
        when 'payment_term_exclusive'
          terms = self.policy_premium_item_payment_terms.references(:policy_premium_payment_terms).includes(:policy_premium_payment_term)
                                                        .references(:line_items).includes(:line_item)
                                                        .where(policy_premium_payment_terms: { prorated: true })
                                                        .select{|ppit| !ppit.policy_premium_payment_term.intersects?(self.policy_premium.prorated_first_moment, self.policy_premium.prorated_last_moment) }
          terms.each do |ppipt|
            next if ppipt.line_item.nil?
            created = ppipt.line_item.line_item_reductions.create(
              reason: "Proration Adjustment",
              amount_interpretation: 'max_total_after_reduction',
              amount: 0,
              refundability: refunds_allowed ? 'cancel_or_refund' : 'cancel_only',
              proration_interaction: 'is_proration'
            )
            unless created.id
              error_message = "Failed to create LineItemReduction for LineItem ##{ppipt.line_item_id}; errors: #{created.errors.to_h}"
              raise ActiveRecord::Rollback
            end
          end
        when 'payment_term_inclusive'
          terms = self.policy_premium_item_payment_terms.references(:policy_premium_payment_terms).includes(:policy_premium_payment_term)
                                                        .references(:line_items).includes(:line_item)
                                                        .where(policy_premium_payment_terms: { prorated: true })
                                                        .select{|ppit| !ppit.policy_premium_payment_term.is_contained_in?(self.policy_premium.prorated_first_moment, self.policy_premium.prorated_last_moment) }
          terms.each do |ppipt|
            next if ppipt.line_item.nil?
            created = ppipt.line_item.line_item_reductions.create(
              reason: "Proration Adjustment",
              amount_interpretation: 'max_total_after_reduction',
              amount: 0,
              refundability: refunds_allowed ? 'cancel_or_refund' : 'cancel_only',
              proration_interaction: 'is_proration'
            )
            unless created.id
              error_message = "Failed to create LineItemReduction for LineItem ##{ppipt.line_item_id}; errors: #{created.errors.to_h}"
              raise ActiveRecord::Rollback
            end
          end
      end
      # mark the proration as applied
      unless self.update(proration_pending: false)
        error_message = "Failed to mark PolicyPremiumItem ##{self.id} as proration_pending: false; errors: #{self.errors.to_h}"
        raise ActiveRecord::Rollback
      end
    end
    return error_message
  end

  # this is expected to be called from within a transaction, with self.policy_premium_item_commissions & an array of collating commissions already locked (and passed as an array)
  def attempt_commission_update(reason, locked_ppic_array, locked_commission_hash)
    ppits = nil
    if self.commission_calculation == 'group_by_transaction'
      ppits = ::PolicyPremiumItemTransaction.where(pending: true, policy_premium_item: self).order(id: :asc).lock.to_a
    end
    ppics = locked_ppic_array
    ppics.sort!
    approx_100 = ppics.inject(0.to_d){|sum,ppic| sum + ppic.percentage } # just in case the decimal %s somehow add up to 99.99 or something (which should be impossible, but better safe than sorry)
    ppic_total_due = ppics.inject(0){|sum,ppic| sum + ppic.total_expected }
    ppic_total_received = ppics.inject(0){|sum,ppic| sum + ppic.total_received }
    # distribute total changes
    if ppic_total_due != self.total_due
      total_assigned = 0
      last_percentage = 0.to_d
      ppics.each do |ppic|
        last_percentage += ppic.percentage
        ppic.total_expected = ((self.total_due * last_percentage) / approx_100).floor - total_assigned
        total_assigned += ppic.total_expected
      end
      ppics.each{|ppic| return { success: false, error: ppic.errors.to_h.to_s, record: ppic } unless ppic.save }
    end
    # distribute received changes & make commission items
    commission_items = []
    if ppic_total_received != self.total_received
      total_assigned = 0
      last_percentage = 0.to_d
      ppics.each do |ppic|
        last_percentage += ppic.percentage
        new_total_received = ((self.total_received * last_percentage) / approx_100).floor - total_assigned
        total_assigned += new_total_received
        acat = (reason.respond_to?(:analytics_category) ? reason.analytics_category : reason.respond_to?(:line_item) ? reason.line_item&.analytics_category : nil) || 'other'
        case self.commission_calculation
          when 'as_received'
            commission_items.push(::CommissionItem.new(
              amount: new_total_received - ppic.total_received,
              commission: locked_commission_hash[ppic.recipient],
              commissionable: ppic,
              reason: reason,
              analytics_category: acat
            )) unless ppic.total_received == new_total_received || !ppic.payable?
          when 'no_payments'
            # do nothing
          when 'group_by_transaction'
            the_reason = (reason.class == ::LineItemChange ? reason.reason : reason)
            transaction = ppits.find do |ppit|
              ppit.recipient_type == ppic.recipient_type && ppit.recipient_id == ppic.recipient_id &&
              ppit.commissionable_type == ppic.commissionable_type && ppit.commissionable_id == ppic.commissionable_id &&
              ppit.reason_type == the_reason.class.name && ppit.reason_id == the_reason.id &&
              ppit.analytics_category == acat
            end || ::PolicyPremiumItemTransaction.new(
              amount: 0,
              pending: true,
              recipient: ppic.recipient,
              commissionable: ppic,
              reason: reason.class == ::LineItemChange ? reason.reason : reason,
              policy_premium_item: self,
              analytics_category: acat
            )
            transaction.amount += new_total_received - ppic.total_received
            transaction.create_commission_items_at = Time.current + self.commission_creation_delay_hours.hours
            return { success: false, error: transaction.errors.to_h.to_s, record: transaction } unless transaction.save!
            transaction_membership = ::PolicyPremiumItemTransactionMembership.create(
              policy_premium_item_transaction: transaction,
              member: reason
            )
            return { success: false, error: transaction_membership.errors.to_h.to_s, record: transaction_membership } unless transaction_membership.save!
        end
        ppic.total_received = new_total_received
        ppic.total_commission = new_total_received unless !ppic.payable?
      end
      ppics.each{|ppic| return { success: false, error: ppic.errors.to_h.to_s, record: ppic } unless ppic.save }
      commission_items.each{|ci| return { success: false, error: ci.errors.to_h.to_s, record: ci } unless ci.save }
    end
    # done
    return { success: true, commission_items: commission_items }
  end
  
  
  private
  
    def hidden_false_unless_fee_or_tax
      self.errors.add(:hidden, "cannot be true unless category is 'fee' or 'tax'") unless !self.hidden || ['fee', 'tax'].include?(self.category)
    end
  
    def set_missing_total_data
      # for convenience, so you don't have to set all of them on create
      val = [self.original_total_due, self.total_due].compact.first
      self.original_total_due = val if self.original_total_due.nil?
      self.total_due = val if self.total_due.nil?
    end
    
    def setup_commissions
      begin
        case self.commission_calculation
          when 'no_payments'
            # don't do anything
          when 'as_received'
            case self.recipient
              when ::CommissionStrategy
                external_mode = false
                last_percentage = 0.to_d
                total_assigned = 0
                payment_order = 0
                self.recipient.get_chain.each do |cs|
                  total_expected = ((self.total_due * cs.percentage) / 100.to_d).floor - total_assigned
                  total_assigned += total_expected
                  external_mode = true if cs == self.collection_plan
                  ::PolicyPremiumItemCommission.create!(
                    policy_premium_item: self,
                    recipient: cs.recipient,
                    commission_strategy_id: cs.id,
                    payability: external_mode || cs.recipient == self.collection_plan ? 'external' : 'internal',
                    status: 'quoted',
                    total_expected: total_expected,
                    total_received: 0,
                    percentage: cs.percentage - last_percentage,
                    payment_order: payment_order
                  )
                  payment_order += 1
                  last_percentage = cs.percentage
                end
              else
                ::PolicyPremiumItemCommission.create!(
                  policy_premium_item: self,
                  recipient: self.recipient,
                  payability: self.recipient == self.collection_plan ? 'external' : 'internal',
                  status: 'quoted',
                  total_expected: self.total_due,
                  total_received: 0,
                  percentage: 100,
                  payment_order: 0
                )
            end # end recipient case
        end # end commission_calculation case
      rescue ActiveRecord::RecordInvalid => e
        errors.add(:policy_premium_item_commission, "could not be created (#{e.record.errors.to_h})")
        raise ActiveRecord::RecordInvalid, self
      end
    end
end








