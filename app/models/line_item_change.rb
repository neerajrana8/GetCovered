

class LineItemChange < ApplicationRecord
  belongs_to :line_item
  belongs_to :reason,
    polymorphic: true
  belongs_to :handler,
    polymorphic: true,
    optional: true
    
  enum field_changed: {
    total_received: 0,
    total_due: 1
  }

  validates_presence_of :field_changed
  validates :amount, numericality: { :greater_than_or_equal_to => 0 }
end
