class LeadsPremiumTotalCalculateJob < ApplicationJob
  queue_as :default

  def perform(*args)
    # Do something later
    leads = Lead.where(premium_total: nil)
    leads.find_in_batches.with_index do |group, _|
      group.each do |lead|
        premium_total = lead.user&.policy_applications&.last&.policy_quotes&.last&.policy_premium&.total
        lead.update_columns(premium_total: premium_total)
      end
    end
  end

end
