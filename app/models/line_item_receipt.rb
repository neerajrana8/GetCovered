

class LineItemReceipt < ApplicationRecord
  belongs_to :line_item
  belongs_to :reason,
    polymorphic: true
  belongs_to :commission_item,
    optional: true

  validates :amount, numericality: { :greater_than_or_equal_to => 0 }
end
