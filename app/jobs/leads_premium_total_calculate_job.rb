class LeadsPremiumTotalCalculateJob < ApplicationJob
  queue_as :default

  def perform(*args)
    # Do something later
    leads = Lead.where(premium_total: nil).where('premium_last_updated_at < ?', 1.day.ago)
    leads.find_in_batches.with_index do |group, _|
      group.each do |lead|
        premium_total = lead.user&.policy_applications&.last&.policy_quotes&.last&.policy_premium&.total
        lead.update_columns(premium_total: premium_total, premium_last_update_at: DateTime.now)
      end
    end
  end

end
