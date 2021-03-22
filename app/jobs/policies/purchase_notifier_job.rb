class Policies::PurchaseNotifierJob < ApplicationJob
  queue_as :default

  def perform(policy)
    @policy = policy

    Policies::PurchaseMailer.with(policy: self).get_covered.deliver

    @policy.agency.staffs.each do |staff|
      setting = staff.notification_settings.where(action: "purchase").take
      Policies::PurchaseMailer.with(policy: self, staff: staff).agency.deliver if setting.enabled?
    end

    unless @policy.account.nil?
      @policy.account.staffs.each do |staff|
        setting = staff.notification_settings.where(action: "purchase").take
        Policies::PurchaseMailer.with(policy: self, staff: staff).account.deliver if setting.enabled?
      end
    end

  end

end
