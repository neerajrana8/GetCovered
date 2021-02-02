class PolicyPremiumItem < ApplicationRecord
  # Associations
  belongs_to :policy_premium  # the policy_premium to which this item applies
  belongs_to :recipient,      # who receives this money (generally a Carrier, Agent, or CommissionStrategy)
    polymorphic: true
  belongs_to :collector       # which Carrier/Agent actually collects the money from users
    polymorphic: true
  belongs_to :fee,            # what Fee this item corresponds to, if any
    optional: true
  # Validations
  validates_presence_of :title
  validates_presence_of :category
  validates_inclusion_of :amortized, in: [true, false]
  validates_inclusion_of :external, in: [true, false]
  validates_inclusion_of :preprocessed, in: [true, false]
  validates :original_total_due, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_due, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_received, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_processed, numericality: { :greater_than_or_equal_to => 0 }
  # Enums
  enum category: {
    fee: 0,
    premium: 1,
    special_premium: 2,
    tax: 3
  }
  # Public Class Methods
  def from_fee(fee)
    ::PolicyPremiumItem.new(
      recipient: ###MOOSE WARNING FILL OUT #####,
      fee: fee,
      title: fee.title || "#{(fee.amortized || fee.per_payment) ? "Amortized " : ""} Fee",
      category: "fee",
      amortized: fee.amortized || fee.per_payment,
      external: false, # MOOSE WARNING: when should this be true?
      preprocessed: false, # MOOSE WARNING: when should this be true?
      original_total_due: fee.amount * (fee.per_payment ? PAYMENT_COUNT : 1), # MOOSE WARNING: PAYMENT_COUNT from where???
      #### MOOSE WARNING: this is no good, fees can be percentages ########
    )
  end
  # Public Instance Methods
end
