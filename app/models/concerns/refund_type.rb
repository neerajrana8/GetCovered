#
# RefundType Concern
# file: app/models/concerns/refund_type.rb

module RefundType
  extend ActiveSupport::Concern

  def signed_amount
    -self.amount
  end
end
