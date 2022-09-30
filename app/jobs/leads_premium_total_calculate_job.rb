class LeadsPremiumTotalCalculateJob < ApplicationJob
  queue_as :default

  def perform(*args)
    # Do something later
    leads = Lead.where(premium_total: nil)
    leads.find_in_batches.with_index do |group, _|
      group.each do |lead|

      end
    end
  end

end
