class ExecuteStripeRefundsJob < ApplicationJob
  queue_as :default

  def perform(refunds = nil)
    case refunds
      when ::StripeRefund
        refunds.execute
      when ::Array
        refunds.each{|r| r.execute }
      when nil
        ::StripeRefund.where(status: 'awaiting_execution').each{|r| r.execute }
    end
  end

end
