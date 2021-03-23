class Policies::PurchaseNotifierJob < ApplicationJob
  queue_as :default

  def perform(policy_id)
    @policy = Policy.find(policy_id)

    Policies::PurchaseMailer.with(policy: @policy).get_covered.deliver

    @policy.agency.staffs.each do |staff|
      setting = staff.notification_settings.where(action: "purchase").take
      Policies::PurchaseMailer.with(policy: @policy, staff: staff).agency.deliver if setting.enabled?
    end

    unless @policy.account.nil?
      @policy.account.staffs.each do |staff|
        setting = staff.notification_settings.where(action: "purchase").take
        Policies::PurchaseMailer.with(policy: @policy, staff: staff).account.deliver if setting.enabled?
      end
    end

  end

end
