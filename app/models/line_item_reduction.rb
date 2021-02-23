class LineItemReduction < ApplicationRecord

  belongs_to :line_item
  belongs_to :dispute,
    optional: true
  belongs_to :refund,
    optional: true
    
  has_one :invoice,
    through: :line_item
  
  before_create :shift_due_to_reducing,

  scope :pending, -> { where(pending: true) }
  
  enum refundability: { # these are ordered descending during processing by Invoice#process_reductions, so their numerical values matter! we want to do disputes and refunds first, then pure cancellations.
    cancel_only: 0,
    cancel_or_refund: 1,
    dispute_resolution: 2
  }
  enum proration_interaction: {
    shared: 0,        # If we reduce by $10, and later a proration removes $5, the total reduction will be $10 (i.e. the prorated 5 will be part of the already-cancelled/refunded 10)
    duplicated: 1,    # If we reduce by $10, and later a proration removes $5, the total reduction will be $15, unless the line item TOTAL is less than $15, in which case it will be completely reduced (i.e. the proration attempts to apply as a separate, non-overlapping reduction when possible)
    reduced: 2        # If the proratable total is $20 and we reduce by $10, then a 50% proration will reduce 50% of the remaining $10 instead of the original $20, i.e. will reduce by 5 additional dollars (i.e. we reduce this and modify the totals so that it is as if this had never been part of the total at all)
  }
  enum stripe_refund_reason: {
    requested_by_customer: 0,
    duplicate: 1,
    fraudulent: 2
  }
  
  def shift_due_to_reducing
    error_message = nil
    ActiveRecord::Base.transaction do
      self.invoice.lock!
      self.line_item.lock!
      to_shift = [self.amount, self.invoice.total_due, self.line_item.total_due].min
      unless self.invoice.update(total_due: self.invoice.total_due - to_shift, total_reducing: self.invoice.total_reducing + to_shift) &&
             self.line_item.update(total_due: self.line_item.total_due - to_shift, total_reducing: self.line_item.total_reducing + to_shift)
        error_message = "failed to be added to invoice/line item total_reducing values"
        raise ActiveRecord::Rollback
      end
    end
    unless error_message.nil?
      self.errors.add(:amount, error_message)
      throw(:abort)
    end
  end

end








