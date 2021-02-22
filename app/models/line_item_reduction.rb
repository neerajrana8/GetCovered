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








