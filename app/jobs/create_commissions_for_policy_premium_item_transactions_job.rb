class CreateCommissionsForPolicyPremiumItemTransactionsJob < ApplicationJob

  def perform(*_args)
    ppits = ::PolicyPremiumItemTransaction.where(pending: true).where("create_commission_items_at <= ?", Time.current).order("policy_premium_item_id asc, id asc")
    ppits.each do |ppit|
      ppit.unleash_commission_item!
    end
  end
end
