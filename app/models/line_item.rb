# frozen_string_literal: true

class LineItem < ApplicationRecord
  belongs_to :invoice

  validates_presence_of :title
  validates_presence_of :price
  validates_presence_of :refundability
  validates_presence_of :category
  validates_presence_of :collected
  validates_presence_of :proration_reduction
  
  enum refundability: {
    no_refund: 0,                         # if we cancel, no refund
    prorated_refund: 1,                   # if we cancel, prorated refund
    complete_refund_before_term: 2,       # if we cancel before term start, complete refund, otherwise no refund
    complete_refund_during_term: 3,       # if we cancel before or during term, complete refund, otherwise no refund
    complete_refund_before_due_date: 4    # if we cancel before the due date, complete refund, otherwise no refund
  }
  
  enum category: {
    uncategorized: 0,
    base_premium: 1,
    special_premium: 2,
    taxes: 3,
    deposit_fees: 4,
    amortized_fees: 5
  }
  
  def adjusted_price
    self.price - self.proration_reduction
  end
end
