module Reports
  class DailySalesAllJob < ApplicationJob
    queue_as :default

    def perform
      # We generate reports for the New York time zone
      # because of the difference between PST and EDT is only 3 hours and we start the job at 4AM PT at the moment 
      # of that fix everything was ok
      range_end = Time.zone.now.yesterday.in_time_zone('Eastern Time (US & Canada)').end_of_day.to_i
      range_start_yesterday = Time.zone.now.yesterday.in_time_zone('Eastern Time (US & Canada)').beginning_of_day.to_i
      range_start_week = (Time.zone.now - 7.days).in_time_zone('Eastern Time (US & Canada)').beginning_of_day.to_i
      range_start_thirty = (Time.zone.now - 30.days).in_time_zone('Eastern Time (US & Canada)').beginning_of_day.to_i

      Agency.all.pluck(:id).each do |agency_id|
        DailySalesJob.perform_later(agency_id, 'Agency', range_start_yesterday, range_end)
        DailySalesJob.perform_later(agency_id, 'Agency', range_start_week, range_end)
        DailySalesJob.perform_later(agency_id, 'Agency', range_start_thirty, range_end)
      end

      Account.all.pluck(:id).each do |account_id|
        DailySalesJob.perform_later(account_id, 'Account', range_start_yesterday, range_end)
        DailySalesJob.perform_later(account_id, 'Account', range_start_week, range_end)
        DailySalesJob.perform_later(account_id, 'Account', range_start_thirty, range_end)
      end
    end
  end
end
