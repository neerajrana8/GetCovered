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
  validates_inclusion_of :all_received, in: [true, false]
  validates_inclusion_of :all_processed, in: [true, false]
  
  
  enum refundability: {
    no_refund: 0,                         # if we cancel, no refund
    prorated_refund: 1                    # if we cancel, prorated refund
  } # WARNING: if you add to this, you need to modify the <=> implementation and possibly some code in Invoice
  
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
  
  # Orders them so that lesser full_refund_before_date < greater full_refund_before_date,
  # where instances with the same date are ordered so that no_refund < prorated_refund,
  # and instances with no date are earlier than all others if no_refund and later than all others if prorated_refund.
  # (Why? Because we distribute funds across line items in this order and refund it in the reverse order;
  #  this order ensures that if we refund multiple chunks at different times, the amount we have to refund is minimized.)
  def <=>(other)
    if self.full_refund_before_date.nil? && other.full_refund_before_date.nil?
      self.class.refundabilities[self.refundability] <=> self.class.refundabilities[other.refundability]
    elsif self.full_refund_before_date.nil?
      self.refundability == 'no_refund' ? -1 : 1
    elsif other.full_refund_before_date.nil?
      other.refundability == 'no_refund' ? 1 : -1
    else
      to_return = (self.full_refund_before_date <=> other.full_refund_before_date)
      if to_return != 0
        to_return
      else
        self.class.refundabilities[self.refundability] <=> self.class.refundabilities[other.refundability]
      end
    end
  end
  
end
