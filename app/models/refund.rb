class Refund < ApplicationRecord

  belongs_to :invoice
  
  has_many :stripe_refunds
  has_many :line_item_reductions
  
  has_many :disputes,
    through: :line_item_reductions
  
  validates_inclusion_of :complete, in: [true, false]
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :amount_refunded, numericality: { greater_than_or_equal_to: 0 }
  validates :amount_returned_by_dispute, numericality: { greater_than_or_equal_to: 0 }
  
  def execute
    return nil if self.complete
    error_message = "Failed to execute Refund"
    created_refunds = []
    self.with_lock do
      ActiveRecord::Base.transaction(requires_new: true) do
        # bookkeeping
        self.line_item_reductions.each do |lir|
          case lir.refundability
            when 'cancel_or_refund'
              self.amount += lir.amount_refunded
              self.refund_reasons.push(lir.reason)
            when 'dispute_resolution'
              self.amount += lir.amount_refunded
              self.amount_returned_by_dispute += lir.amount_refunded
              self.refund_reasons.push(lir.reason)
            else
              # ignore
          end
        end
        self.refund_reasons.uniq!
        self.complete = true
        self.save!
        # stripe refund creation (since refunds are on specific charges, and since we want to keep single stripe_reasons together, we may need to create several StripeRefunds--usually this will be overkill and we will just create one)
        charges = self.invoice.stripe_charges.succeeded.order(id: :asc).lock!.to_a
        amount_actually_refunded = 0
        self.line_item_reductions.cancel_or_refund.group_by{|lir| lir.stripe_refund_reason || 'requested_by_customer' }
                                                  .transform_values do |lirs| {
                                                      amount: lirs.inject(0){|sum,lir| sum + lir.amount_refunded },
                                                      reasons: lirs.map{|lir| lir.reason }.uniq
                                                    }
                                                  end.each do |stripe_reason, refund_info|
          amount_left = refund_info[:amount]
          charges.each do |charge|
            to_refund = [charge.amount - charge.amount_refunded, amount_left].min
            next if to_refund <= 0
            created = ::StripeRefund.create(
              refund: self,
              stripe_charge: charge,
              amount: to_refund,
              stripe_reason: stripe_reason,
              full_reasons: refund_info[:reasons]
            )
            raise ActiveRecord::Rollback if created.id.nil?
            raise ActiveRecord::Rollback unless charge.update(amount_refunded: charge.amount_refunded + to_refund)
            created_refunds.push(created)
            amount_actually_refunded += to_refund
            amount_left -= to_refund
            break if amount_left == 0
          end
        end
        raise ActiveRecord::Rollback unless self.update(amount_refunded: amount_actually_refunded)
        error_message = nil # if we got here, make sure we mark ourselves as having succeeded
      end # end transaction
    end # end lock
    if error_message.nil?
      ::ExecuteStripeRefundsJob.perform_later(created_refunds)
    end
    return error_message
  end

end
