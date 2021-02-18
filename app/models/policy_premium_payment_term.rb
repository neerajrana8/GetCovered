class PolicyPremiumPaymentTerm < ApplicationRecord

  # Associations
  belongs_to :policy_premium
  
  has_one :policy_quote,
    through: :policy_premium
  has_one :policy,
    through: :policy_quote
  has_many :policy_premium_item_payment_terms
  has_many :line_items,
    through: :policy_premium_item_payment_terms

  # Callbacks
  before_validation :set_missing_term_data,
    on: :create,
    if: Proc.new{|ppit| ppit.original_term_first_moment.nil? || ppit.original_term_last_moment.nil? || ppit.term_last_moment.nil? || ppit.term_first_moment.nil? }
  before_save :set_proportion_to_zero,
    if: Proc.new{|ppit| ppit.cancelled }

  # Validations
  validates_presence_of :original_term_first_moment
  validates_presence_of :original_term_last_moment
  validates_presence_of :term_first_moment
  validates_presence_of :term_last_moment
  validates_presence_of :time_resolution
  validates_presence_of :status
  validates :default_weight,
    numericality: { :greater_than_or_equal_to => 0 },
    allow_blank: true
  validate :validate_term
  
  # Enums
  enum time_resolution: {
    day: 0
  }
  enum status: {
    active: 0,
    cancelled: 1
  }
  
  # Public Class Methods
  
  # Public Instance Methods
  
  
  def <=>(other)
    tr = self.original_first_moment <=> other.original_first_moment
    return tr == 0 ? self.original_last_moment <=> other.original_last_moment : tr
  end
  
  def ticks(n)
    case self.time_resolution
      when day
        return n.days
    end
  end
  
  def update_proration(new_first_moment, new_last_moment)
    if new_first_moment > new_last_moment
      self.errors.add(:proration_attempt, "failed, since provided last moment preceded provided first moment")
      return false
    end
    case self.time_resolution
      when 'day'
        nfm = new_first_moment.to_date
        nlm = new_last_moment.to_date
        fm = self.first_moment.to_date
        lm = self.last_moment.to_date
        if fm > nlm || lm < nfm
          return self.update(last_moment: self.first_moment, cancelled: true) # this term has been prorated into nothingness
        elsif nfm <= fm && nlm >= lm
          return self # no changes
        else
          # we've prorated for real
          ofm = self.original_first_moment.to_date
          olmm = self.original_last_moment.to_date
          fm = nfm if nfm > fm
          lm = nlm if nlm < lm
          return self.update(first_moment: fm.beginning_of_day, last_moment: lm.end_of_day, unprorated_proportion: ((lm - fm).to_i + 1).to_d / ((olm - ofm).to_i + 1).to_d)
        end
    end
    self.errors.add(:proration_attempt, "failed, since time_resolution value was not recognized")
    return false
  end  
  
  
  private
  
    def set_missing_term_data
      # for convenience so you don't have to set both sets on creation
      self.term_first_moment = self.original_term_first_moment if self.term_first_moment.nil?
      self.term_last_moment = self.original_term_last_moment if self.term_last_moment.nil?
      self.original_term_first_moment = self.term_first_moment if self.original_term_first_moment.nil?
      self.original_term_last_moment = self.term_last_moment if self.original_term_last_moment.nil?
    end
    
    def set_proportion_to_zero
      self.unprorated_proportion = 0
    end
  
    def validate_term
      errors.add(:original_term_last_moment, I18n.t("policy_premium_payment_term.original_term_last_moment_invalid")) unless self.original_term_last_moment >= self.original_term_first_moment
      errors.add(:term_last_moment, I18n.t("policy_premium_payment_term.term_last_moment_invalid")) unless self.term_last_moment >= self.term_first_moment
      errors.add(:term_first_moment, I18n.t("policy_premium_payment_term.term_first_moment_too_early")) unless self.term_first_moment >= self.original_term_first_moment
      errors.add(:term_last_moment, I18n.t("policy_premium_payment_term.term_last_moment_too_late")) unless self.term_last_moment <= self.original_term_last_moment
    end
end








