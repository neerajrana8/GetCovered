class PolicyPremiumItem < ApplicationRecord
  # Associations
  belongs_to :policy_premium  # the policy_premium to which this item applies
  belongs_to :recipient,      # who receives this money (generally a Carrier, Agent, or CommissionStrategy)
    polymorphic: true
  belongs_to :collector,      # which Carrier/Agent actually collects the money from users
    polymorphic: true
  belongs_to :fee,            # what Fee this item corresponds to, if any
    optional: true
    
  has_one :billing_strategy,
    through: :policy_premium
  has_one :policy_quote,
    through: :policy_premium
  has_many :policy_premium_item_payment_terms,
    autosave: true # MOOSE WARNING: does this suffice?
  has_many :line_items,
    through: :policy_premium_item_terms

  # Callbacks
  before_validation :set_missing_total_data,
    on: :create,
    if: Proc.new{|ppi| ppi.original_total_due.nil? || ppi.total_due.nil? }

  # Validations
  validates_presence_of :title
  validates_presence_of :category
  validates_presence_of :rounding_error_distribution
  validates :original_total_due, numericality: { :greater_than_or_equal_to => 0 }
  validates :preproration_total_due, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_due, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_received, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_processed, numericality: { :greater_than_or_equal_to => 0 }
  validates_presence_of :proration_calculation
  validates_inclusion_of :proration_refunds_allowed, in: [true, false]
  validates_inclusion_of :preprocessed, in: [true, false]
  
  # Enums etc.
  enum category: {
    fee: 0,
    premium: 1,
    tax: 2
  }
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
  }
  
  # Public Class Methods
  
  # Public Instance Methods
  
  def generate_line_items
    # verify we haven't already done this & clean our PolicyPremiumItemPaymentTerms
    return "Line items already scheduled" unless self.line_items.blank?
    ::PolicyPremiumItemPaymentTerm.prepare_clean_slate(self.policy_premium_item_payment_terms)
    to_return = self.policy_premium_item_payment_terms.order(original_first_moment: :asc, original_last_moment: :desc)
    # calculate line item totals
    case self.rounding_error_distribution
      when 'dynamic_forward', 'dynamic_reverse'
        total_left = self.preproration_total_due
        weight_left = to_return.inject(0){|sum,pt| sum + pt.weight }.to_d
        reversal = (self.rounding_error_distribution == 'dynamic_reverse' ? :reverse : :itself)
        to_return = to_return.send(reversal).each do |pt|
          pt.preproration_total_due = ((pt.weight / weight_left) * total_left).floor
          total_left -= pt.preproration_total_due
          weight_left -= pt.weight
        end
      when 'first_payment_simple', 'last_payment_simple', 'first_payment_multipass', 'last_payment_multipass'
        total_weight = to_return.inject(0){|sum,pt| sum + pt.weight }.to_d
        multiple_passes = self.rounding_error_distribution.end_with?("multipass")
        to_distribute = self.preproration_total_due
        loop do
          distributed = 0
          to_return.each do |pt|
            li_total = ((pt.weight / total_weight) * to_distribute).floor
            pt.preproration_total_due += li_total
            distributed += li_total
          end
          to_distribute -= distributed
          break if distributed == 0 || !multiple_passes
        end
        reversal = (self.rounding_error_distribution.start_with?('first_payment') ? :each : :reverse_each)
        to_return.send(reversal).find{|tp| tp.preproration_total_due > 0 }.preproration_total_due += to_distribute
    end
    # save changes
    to_return.each{|tr| tr.save }
    # return line items MOOSE WARNING: save these instead, no?
    return to_return.map do |pt|
      pt.preproration_total_due == 0 ? nil : LineItem.new(
        chargeable: pt,
        title: self.title,
        original_total_due: pt.original_total_due,
        total_due: pt_original_total_due,
        total_received: 0
      )
    end
  end
  
  def apply_proration
    return nil unless self.proration_pending && self.preproration_modifiers == 0 && self.policy_premium.prorated
    error_message = nil
    ActiveRecord::Base.transaction(requires_new: true) do
      # lock our bois
      invoice_array = ::Invoice.where(id: self.line_items.map{|li| li.invoice_id }).order(id: :asc).lock.to_a
      line_item_array = self.line_items.order(id: :asc).lock.to_a
      self.lock!
      # flee if there's an issue (yes, this is redundant; we checked at first in the hopes of avoiding locking overhead, now we are checking for real, within the lock
      return nil unless self.proration_pending && self.proration_modifiers == 0
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
            created = ppipt.line_item.line_item_reductions.create(
              reason: "Proration Adjustment",
              amount_interpretation: 'max_total_after_reduction',
              amount: [(ppipt.policy_premium_payment_term.unprorated_proportion * ppipt.preproration_total_due).ceil - ppipt.duplicatable_reduction_total, 0].max,
              # MOOSE WARNING: the above handling of amount presents a potential problem... because we don't increment preproration_modifiers for duplicatable reductions... it could change after we are issued but before we are executed...
              refundability: self.proration_refunds_allowed ? 'cancel_or_refund' : 'cancel_only',
              proration_interaction: 'shared'
            )
            unless created.id
              error_message = "Failed to create LineItemReduction for LineItem ##{ppipt.line_item_id}; errors: #{created.errors.to_h}"
              raise ActiveRecord::rollback
            end
          end
        when 'payment_term_exclusive'
          terms = self.policy_premium_item_payment_terms.references(:policy_premium_payment_terms).includes(:policy_premium_payment_term)
                                                        .references(:line_items).includes(:line_item)
                                                        .where(policy_premium_payment_terms: { prorated: true })
                                                        .select{|ppit| !ppit.policy_premium_payment_term.intersects?(self.policy_premium.prorated_first_moment, self.policy_premium.prorated_last_moment) }
          terms.each do |ppipt|
            created = ppipt.line_item.line_item_reductions.create(
              reason: "Proration Adjustment",
              amount_interpretation: 'max_total_after_reduction',
              amount: 0,
              refundability: self.proration_refunds_allowed ? 'cancel_or_refund' : 'cancel_only',
              proration_interaction: 'shared'
            )
            unless created.id
              error_message = "Failed to create LineItemReduction for LineItem ##{ppipt.line_item_id}; errors: #{created.errors.to_h}"
              raise ActiveRecord::rollback
            end
          end
        when 'payment_term_inclusive'
          terms = self.policy_premium_item_payment_terms.references(:policy_premium_payment_terms).includes(:policy_premium_payment_term)
                                                        .references(:line_items).includes(:line_item)
                                                        .where(policy_premium_payment_terms: { prorated: true })
                                                        .select{|ppit| !ppit.policy_premium_payment_term.is_contained_in?(self.policy_premium.prorated_first_moment, self.policy_premium.prorated_last_moment) }
          terms.each do |ppipt|
            created = ppipt.line_item.line_item_reductions.create(
              reason: "Proration Adjustment",
              amount_interpretation: 'max_total_after_reduction',
              amount: 0,
              refundability: self.proration_refunds_allowed ? 'cancel_or_refund' : 'cancel_only',
              proration_interaction: 'shared'
            )
            unless created.id
              error_message = "Failed to create LineItemReduction for LineItem ##{ppipt.line_item_id}; errors: #{created.errors.to_h}"
              raise ActiveRecord::rollback
            end
          end
      end
    end
    return error_message
  end
  
  private
  
    def set_missing_total_data
      # for convenience, so you don't have to set all of them on create
      val = [self.original_total_due, self.preproration_total_due, self.total_due].compact.first
      self.original_total_due = val if self.original_total_due.nil?
      self.preproration_total_due = val if self.preproration_total_due.nil?
      self.total_due = val if self.total_due.nil?
    end
end








