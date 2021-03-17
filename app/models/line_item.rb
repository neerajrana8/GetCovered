# frozen_string_literal: true

class LineItem < ApplicationRecord
  belongs_to :invoice
  belongs_to :chargeable,
    polymorphic: true,
    autosave: true
  belongs_to :policy_quote,
    optional: true
    
  has_many :line_item_changes

  validates_presence_of :title
  validates_inclusion_of :priced_in, in: [true, false]
  validates :original_total_due, numericality: { greater_than_or_equal_to: 0 }
  validates :preproration_total_due, numericality: { greater_than_or_equal_to: 0 }
  validates :total_due, numericality: { greater_than_or_equal_to: 0 }
  validates :total_received, numericality: { greater_than_or_equal_to: 0 }
  validates :duplicatable_reduction_total, numericality: { greater_than_or_equal_to: 0 }
  
  scope :priced_in, -> { where(priced_in: true) }

  enum analytics_category: {
    unknown: 0,
    policy_premium: 1,
    policy_fee: 2,
    policy_tax: 3
  }
  
  def <=>(other)
    (self.id || 0) <=> (other.id || 0) # MOOSE WARNING: implement proper line item sorting by proration refundability if you care
  end
    
    
    
    
end
