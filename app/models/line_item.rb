# frozen_string_literal: true

class LineItem < ApplicationRecord
  include FinanceAnalyticsCategory # provides analytics_category enum

  belongs_to :invoice
  belongs_to :chargeable,
    polymorphic: true,
    autosave: true
  belongs_to :policy_quote,
    optional: true
  belongs_to :policy,
    optional: true
    
  has_many :line_item_changes
  has_many :line_item_reductions

  validates_presence_of :title
  validates_inclusion_of :priced_in, in: [true, false]
  validates :original_total_due, numericality: { greater_than_or_equal_to: 0 }
  validates :preproration_total_due, numericality: { greater_than_or_equal_to: 0 }
  validates :total_due, numericality: { greater_than_or_equal_to: 0 }
  validates :total_received, numericality: { greater_than_or_equal_to: 0 }
  validates :duplicatable_reduction_total, numericality: { greater_than_or_equal_to: 0 }
  
  scope :priced_in, -> { where(priced_in: true) }

  # sort line items from first-to-charge-for to last-to-charge-for
  def <=>(other)
    return (self.id || 0) <=> (other.id || 0) if self.analytics_category == other.analytics_category
    return -(self.analytics_category <=> other.analytics_category) # negative so tax gets paid first
  end
    
    
    
    
end
