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
    if: Proc.new{|ppit| ppit.original_first_moment.nil? || ppit.original_last_moment.nil? || ppit.last_moment.nil? || ppit.first_moment.nil? }
  before_save :set_proportion_to_zero,
    if: Proc.new{|ppit| ppit.cancelled }

  # Validations
  validates_presence_of :original_first_moment
  validates_presence_of :original_last_moment
  validates_presence_of :first_moment
  validates_presence_of :last_moment
  validates_presence_of :time_resolution
  validates :default_weight,
    numericality: { :greater_than_or_equal_to => 0 },
    allow_blank: true
  validate :validate_term
  
  # Enums
  enum time_resolution: {
    day: 0
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
  
  def intersects?(interval_start, interval_end)
    case self.time_resolution
      when 'day'
        is = interval_start.to_date
        ie = interval_end.to_date
        fm = self.first_moment.to_date
        lm = self.last_moment.to_date
        return is <= lm && ie >= fm
    end
  end
  
  def is_contained_in?(interval_start, interval_end)
    case self.time_resolution
      when 'day'
        is = interval_start.to_date
        ie = interval_end.to_date
        fm = self.first_moment.to_date
        lm = self.last_moment.to_date
        return is <= fm && ie >= lm
    end
  end
  
  def cancel
    return self.update(last_moment: self.first_moment, prorated: true, cancelled: true)
  end
  
  def update_proration(new_first_moment, new_last_moment)
    new_first_moment = self.first_moment if new_first_moment.nil?
    new_last_moment = self.last_moment if new_last_moment.nil?
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
          return self.cancel # this term has been prorated into nothingness
        elsif nfm <= fm && nlm >= lm
          return true # no changes
        else
          # we've prorated for real
          ofm = self.original_first_moment.to_date
          olm = self.original_last_moment.to_date
          fm = nfm if nfm > fm
          lm = nlm if nlm < lm
          return self.update(
            first_moment: fm.beginning_of_day,
            last_moment: lm.end_of_day,
            unprorated_proportion: ((lm - fm).to_i + 1).to_d / ((olm - ofm).to_i + 1).to_d,
            prorated: true
          )
        end
    end
    self.errors.add(:proration_attempt, "failed, since time_resolution value was not recognized")
    return false
  end  
  
  
  private
  
    def set_missing_term_data
      # for convenience so you don't have to set both sets on creation
      self.first_moment = self.original_first_moment if self.first_moment.nil?
      self.last_moment = self.original_last_moment if self.last_moment.nil?
      self.original_first_moment = self.first_moment if self.original_first_moment.nil?
      self.original_last_moment = self.last_moment if self.original_last_moment.nil?
    end
    
    def set_proportion_to_zero
      self.unprorated_proportion = 0
    end
  
    def validate_term
      errors.add(:original_last_moment, I18n.t("policy_premium_payment_term.original_last_moment_invalid")) unless self.original_last_moment >= self.original_first_moment
      errors.add(:last_moment, I18n.t("policy_premium_payment_term.last_moment_invalid")) unless self.last_moment >= self.first_moment
      errors.add(:first_moment, I18n.t("policy_premium_payment_term.first_moment_too_early")) unless self.first_moment >= self.original_first_moment
      errors.add(:last_moment, I18n.t("policy_premium_payment_term.last_moment_too_late")) unless self.last_moment <= self.original_last_moment
    end
end








