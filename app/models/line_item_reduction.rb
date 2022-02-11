class LineItemReduction < ApplicationRecord
  attr_accessor :callbacks_disabled

  belongs_to :line_item
  belongs_to :dispute,
    optional: true
  belongs_to :refund,
    optional: true
    
  has_one :invoice,
    through: :line_item
  
  before_create :update_associated_models,
    unless: Proc.new{|lir| lir.callbacks_disabled }
  after_commit :queue_for_processing,
    unless: Proc.new{|lir| lir.callbacks_disabled }

  scope :pending, -> { where(pending: true) }
  
  enum amount_interpretation: {
    max_amount_to_reduce: 0,
    max_total_after_reduction: 1
  }
  enum refundability: { # these are ordered descending during processing by Invoice#process_reductions, so their numerical values matter! we want to do disputes and refunds first, then pure cancellations.
    cancel_only: 0,
    cancel_or_refund: 1,
    dispute_resolution: 2
  }
  enum proration_interaction: {
    shared: 0,        # If we reduce by $10, and later a proration removes $5, the total reduction will be $10 (i.e. the prorated 5 will be part of the already-cancelled/refunded 10)
    duplicated: 1,    # If we reduce by $10, and later a proration removes $5, the total reduction will be $15, unless the line item TOTAL is less than $15, in which case it will be completely reduced (i.e. the proration attempts to apply as a separate, non-overlapping reduction when possible)
    reduced: 2,       # If the proratable total is $20 and we reduce by $10, then a 50% proration will reduce 50% of the remaining $10 instead of the original $20, i.e. will reduce by 5 additional dollars (i.e. we reduce this and modify the totals so that it is as if this had never been part of the total at all)
    is_proration: 3   # This IS a proration.
  }
  enum stripe_refund_reason: {
    requested_by_customer: 0,
    duplicate: 1,
    fraudulent: 2
  }
  
  def get_amount_to_reduce(li = self.line_item)
    to_reduce_ceiling = self.refundability == 'cancel_only' ? li.total_due - li.total_received : li.total_due
    to_reduce = case self.proration_interaction
      when 'is_proration'
        self.amount_interpretation == 'max_amount_to_reduce' ?
        li.total_due - (li.preproration_total_due - self.amount - li.duplicatable_reduction_total) # same as below, except that the desired max total_due is li.preproration_total_due - self.amount
        : li.total_due - (self.amount - li.duplicatable_reduction_total) # self.amount is our desired max total_due; but DRT reductions should remain non-overlapping with proration reductions, i.e. we need to subtract them to get the REAL desired max total_due
      else
       self.amount_interpretation == 'max_amount_to_reduce' ?
        self.amount - self.amount_successful
        : li.total_due - self.amount
    end
    to_reduce = to_reduce_ceiling if to_reduce > to_reduce_ceiling
    to_reduce = 0 if to_reduce < 0
    return to_reduce
  end
  
  def queue_for_processing
    # give it a brief delay in case we're creating several LIRs at once (so they get put on the same Refund object)
    HandleLineItemReductionsJob.set(wait: 30.seconds).perform_later(invoice_id: self.line_item.invoice_id)
  end

  private
  
    def update_associated_models
      error_message = nil
      ActiveRecord::Base.transaction(requires_new: true) do
        # move the invoice and line item totals into the reducing column (so that admins know the total that currently applies, and so that in multiple payment situations the user doesn't overpay & force us to issue a refund unnecessarily)
        self.invoice.lock!
        self.line_item.lock!
        to_shift = self.get_amount_to_reduce
        unless to_shift == 0 || (
                self.invoice.update(total_due: self.invoice.total_due - to_shift, total_payable: [[self.invoice.total_payable - to_shift, self.invoice.total_payable].min, 0].max, total_reducing: self.invoice.total_reducing + to_shift) &&
                self.line_item.update(total_due: self.line_item.total_due - to_shift, total_reducing: self.line_item.total_reducing + to_shift)
               )
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








