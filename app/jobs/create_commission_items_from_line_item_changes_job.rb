class CreateCommissionItemsFromLineItemChangesJob < ApplicationJob
  queue_as :default
  before_perform :set_lics

  def perform(*args)
    @lics.each do |lic|
      ActiveRecord::Base.transaction do
        ppipt = lic.line_item.chargeable
        ppi = ppipt.policy_premium_item
        lic.lock!
        ppipt.lock!
        ppi.lock!
        case lic.field_changed
          when 'total_due'
          when 'total_received'
        
      end
    end
  end

  private

    def set_lics
      @lics = ::LineItemChange.references(:line_items).includes(:line_item).where(handled: false, line_item: { chargeable_type: "PolicyPremiumItemPaymentTerm" })
    end
end
