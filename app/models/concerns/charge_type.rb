#
# ChargeType Concern
# file: app/models/concerns/charge_type.rb

module ChargeType
  extend ActiveSupport::Concern

  def signed_amount
    self.amount
  end
end
