class PolicyPremiumItemTerm < ApplicationRecord

  # Associations
  belongs_to :policy_premium_item
  has_one :line_item,
    as: :chargeable

  # Callbacks
  before_validation :set_missing_term_data,
    on: :create,
    if: Proc.new{|ppit| ppit.original_term_first_moment.nil? || ppit.original_term_last_moment.nil? || ppit.term_last_moment.nil? || ppit.term_first_moment.nil? }

  # Validations
  validates_presence_of :original_term_first_moment
  validates_presence_of :original_term_last_moment
  validates_presence_of :term_first_moment
  validates_presence_of :term_last_moment
  validates_presence_of :time_resolution
  validates_presence_of :status
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
  
  
  private
  
    def set_missing_term_data
      # for convenience so you don't have to set both sets on creation
      self.term_first_moment = self.original_term_first_moment if self.term_first_moment.nil?
      self.term_last_moment = self.original_term_last_moment if self.term_last_moment.nil?
      self.original_term_first_moment = self.term_first_moment if self.original_term_first_moment.nil?
      self.original_term_last_moment = self.term_last_moment if self.original_term_last_moment.nil?
    end
  
    def validate_term
      errors.add(:original_term_last_moment, I18n.t("policy_premium_item_term.original_term_last_moment_invalid")) unless self.original_term_last_moment >= self.original_term_first_moment
      errors.add(:term_last_moment, I18n.t("policy_premium_item_term.term_last_moment_invalid")) unless self.term_last_moment >= self.term_first_moment
      errors.add(:term_first_moment, I18n.t("policy_premium_item_term.term_first_moment_too_early")) unless self.term_first_moment >= self.original_term_first_moment
      errors.add(:term_last_moment, I18n.t("policy_premium_item_term.term_last_moment_too_late")) unless self.term_last_moment <= self.original_term_last_moment
    end
end








