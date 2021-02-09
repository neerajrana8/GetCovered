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
  has_many :policy_premium_item_terms,
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
  
  
  # Useful constants
  ProrationCalculationChargeOrder = [   # the order in which to apply charges to line items, based on proration_calculation (refunds occur in reverse)
    'cancel_or_refund_nothing',
    'cancel_terms_exclusive',
    'cancel_or_refund_terms_exclusive',
    'prorate_per_term',
    'prorate_from_total',
    'cancel_or_refund_terms_inclusive'
  ]
  
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
    per_total: 2,                 # cancel/refund everything in proportion to the amount of the total active policy duration cancelled (i.e. total cancelled amount will be unaffected by how payments were distributed over payment terms)
    payment_term_exclusive: 3,    # cancel/refund every payment term falling completely after the new policy last date
    payment_term_inclusive: 4     # cancel/refund every payment term any portion of which falls after the new policy last date
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
        total_received: 0,
        total_processed: 0
      )
    end
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








