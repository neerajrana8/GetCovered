# frozen_string_literal: true

class LineItem < ApplicationRecord
  belongs_to :invoice
  belongs_to :chargeable,
    polymorphic: true,
    autosave: true
    
  has_many :line_item_changes
  
  before_save :set_all_processed

  validates_presence_of :title
  validates_inclusion_of :priced_in, in: [true, false]
  validates :original_total_due, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_due, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_received, numericality: { :greater_than_or_equal_to => 0 }
  validates :total_processed, numericality: { :greater_than_or_equal_to => 0 }
  validates_inclusion_of :all_processed, in: [true, false]
  
  scope :priced_in, -> { where(priced_in: true) }
  
  def <=>(other)
    (self.id || 0) <=> (other.id || 0) # MOOSE WARNING: implement proper line item sorting by proration refundability
  end
  
  private
  
    def set_all_processed
      self.all_processed = (self.total_processed == self.total_received)
    end
    
    
    
    
end
