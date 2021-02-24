

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
  enum proration_interaction: {
    shared: 0,        # If we reduce by $10, and later a proration removes $5, the total reduction will be $10 (i.e. the prorated 5 will be part of the already-cancelled/refunded 10)
    duplicated: 1,    # If we reduce by $10, and later a proration removes $5, the total reduction will be $15, unless the line item TOTAL is less than $15, in which case it will be completely reduced (i.e. the proration attempts to apply as a separate, non-overlapping reduction when possible)
    reduced: 2        # If the proratable total is $20 and we reduce by $10, then a 50% proration will reduce 50% of the remaining $10 instead of the original $20, i.e. will reduce by 5 additional dollars (i.e. we reduce this and modify the totals so that it is as if this had never been part of the total at all)
  }

  validates_presence_of :field_changed
  validates :amount, numericality: { :greater_than_or_equal_to => 0 }
  validates_presence_of :proration_interaction,
    if: Proc.new{|lic| lic.field_changed == 'total_due' }
end
