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

  # Callbacks
  before_validation :set_amortization_plan,
    if: :will_save_change_to_amortization?

  # Validations
  validates_presence_of :title
  validates_presence_of :category
  validates_presence_of :amortization
  validates_presence_of :amortization_plan
  validates_presence_of :rounding_error_distribution
  validates :original_total_due, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_due, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_received, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_processed, numericality: { :greater_than_or_equal_to => 0 }
  validates_presence_of :proration_calculation
  validates_inclusion_of :preprocessed, in: [true, false]
  
  validate :validate_amortization_plan
  
  
  # Enums
  enum category: {
    fee: 0,
    premium: 1,
    special_premium: 2,
    tax: 3
  }
  enum amortization: {
    all_up_front: 0,
    billing_strategy_spread: 1,
    equal_spread: 2,
    equal_spread_except_first: 3,
    custom_spread: 4,
    custom_spread_dollar_amounts: 5
  }, _prefix: false, _suffix: false
  enum rounding_error_distribution: {
    on_last_payment: 0,
    on_first_payment: 1,
    dynamic: 1
  }, _prefix: true, _suffix: false
  enum proration_calculation: {
    prorate_per_invoice: 0,
    prorate_total: 1
  }
  
  # Public Class Methods
  def from_fee(fee)
    ::PolicyPremiumItem.new(
      recipient: ###MOOSE WARNING FILL OUT #####,
      fee: fee,
      title: fee.title || "#{(fee.amortized || fee.per_payment) ? "Amortized " : ""} Fee",
      category: "fee",
      amortization: fee.amortized ? 'billing_strategy_spread' : fee.per_payment ? 'equal_spread' : 'all_up_front',
      preprocessed: false, # MOOSE WARNING: when should this be true?
      original_total_due: fee.amount * (fee.per_payment ? PAYMENT_COUNT : 1), # MOOSE WARNING: PAYMENT_COUNT from where???
      #### MOOSE WARNING: this is no good, fees can be percentages ########
    )
  end
  
  # Public Instance Methods
  def schedule_line_items
    to_return = nil
    if self.rounding_error_distribution == 'dynamic'
      total_left = self.original_total_due
      weight_left = self.amortization_plan.inject(0){|sum,val| sum + val }.to_d
      to_return = self.amortization_plan.map do |weight|
        li_total = ((weight / weight_left) * total_left).floor
        total_left -= li_total
        weight_left -= weight
        next li_total == 0 ? nil : LineItem.new(
          policy_premium_item: self,
          title: self.title,
          original_total_due: li_total,
          total_due: li_total,
          total_received: 0,
          total_processed: 0 # MOOSE WARNING: no more price, no refundability, no category
        )
      end
    elsif self.rounding_error_distribution == 'on_first_payment' || self.rounding_error_distribution == 'on_last_payment'
      total_weight = self.amortization_plan.inject(0){|sum,val| sum + val }.to_d
      to_return = self.amortization_plan.map do |weight|
        li_total = ((weight / total_weight) * self.original_total_due).floor
        next li_total == 0 ? nil : LineItem.new(
          policy_premium_item: self,
          title: self.title,
          original_total_due: li_total,
          total_due: li_total,
          total_received: 0,
          total_processed: 0 # MOOSE WARNING: no more price, no refundability, no category
        )
      end
      rounding_error = self.original_total_due - to_return.inject(0){|sum,li| sum + li.original_total_due }
      li = to_return[self.rounding_error_distribution == 'on_first_payment' ? 0 : -1]
      li.original_total_due += rounding_error
      li.total_due += rounding_error
    end
    return to_return
  end
  
  
  private
  
    def set_amortization_plan
      self.amortization_plan = case self.amortization
        when 'all_up_front'
          (0...(self.billing_strategy.payments_per_term)).map{|x| x == 0 ? 1 : 0 }
        when 'billing_strategy_spread'
          self.billing_strategy.new_business["payments"].select{|p| p > 0 }
        when 'equal_spread'
          (0...(self.billing_strategy.payments_per_term)).map{|x| 1 }
        when 'equal_spread_except_first'
          (0...(self.billing_strategy.payments_per_term)).map{|x| x == 0 ? 0 : 1 }
        when 'custom_spread'
          self.amortization_plan
        when 'custom_spread_dollar_amounts'
          self.amortization_plan
      end
    end
    
    def validate_amortization_plan
      unless self.amortization_plan.class == ::Array &&
             self.amortization_plan.length == self.billing_strategy.payments_per_term &&
             self.amortization_plan.all?{|x| x.is_a?(::Integer) && x >= 0 } &&
             self.amortization_plan.any?{|x| x != 0 }
        errors.add(:amortization_plan, I18n.t('policy_premium_item_model.amortization_plan_is_invalid'))
      elsif self.amortization == 'custom_spread_dollar_amounts' && self.amortization_plan.inject(0){|sum,v| sum + v } != self.original_total
        errors.add(:amortization_plan, I18n.t('policy_premium_item_model.amortization_plan_sum_invalid'))
      end
    end
end








