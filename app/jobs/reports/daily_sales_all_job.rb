module Reports
  class DailySalesAllJob < ApplicationJob
    queue_as :default

    def perform
      range_end = Time.zone.now.yesterday.end_of_day.to_i
      range_start_yesterday = Time.zone.now.yesterday.beginning_of_day.to_i
      range_start_week = (Time.zone.now - 7.days).beginning_of_day.to_i
      range_start_thirty = (Time.zone.now - 30.days).beginning_of_day.to_i

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
