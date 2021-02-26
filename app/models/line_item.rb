# frozen_string_literal: true

class LineItem < ApplicationRecord
  belongs_to :invoice
  belongs_to :chargeable,
    polymorphic: true,
    autosave: true
    
  has_many :line_item_changes

  validates_presence_of :title
  validates_inclusion_of :priced_in, in: [true, false]
  validates :original_total_due, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_due, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_received, numericality: { :greater_than_or_equal_to => 0 }
  
  scope :priced_in, -> { where(priced_in: true) }
  
  def <=>(other)
    (self.id || 0) <=> (other.id || 0) # MOOSE WARNING: implement proper line item sorting by proration refundability
  end
    
    
    
    
end
