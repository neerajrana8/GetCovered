# frozen_string_literal: true

class LineItem < ApplicationRecord
  belongs_to :invoice
  belongs_to :chargeable,
    polymorphic: true,
    autosave: true

  validates_presence_of :title
  validates_inclusion_of :priced_in, in: [true, false]
  validates :original_total_due, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_due, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_received, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_processed, numericality: { :greater_than_or_equal_to => 0 }
  #validates_inclusion_of :all_received, in: [true, false]
  validates_inclusion_of :all_processed, in: [true, false]
  
  def <=>(other)
    0 # MOOSE WARNING: implement proper line item sorting by proration refundability
    
    
    
  end
  
  
end
