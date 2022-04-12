module Leads
  module LeadsDashboardMethods
    extend ActiveSupport::Concern

    def index
      # start_date = Date.parse(date_params[:start])
      # end_date   = Date.parse(date_params[:end])
      #
      # params[:filter][:last_visit] = if date_params[:start] == date_params[:end]
      #   start_date.all_day
      # else
      #   (start_date.all_day.first..end_date.all_day.last)
      # end
      #
      # # check duplicates in totals?
      # super(:@leads, @substrate, :tracking_url)
      #
      # @stats = {
      #   site_visits: site_visits(@leads),
      #   leads: leads(@leads),
      #   applications: applications(@leads),
      #   not_finished_applications: not_finished_applications(@leads),
      #   conversions: conversions(@leads),
      #   visitors: visitors(@leads),
      #   customers: customers(@leads)
      # }
      #
      # @stats_by = {}
      #
      # if filter_by_day?(start_date, end_date)
      #   start_date.upto(end_date) do |date|
      #     params[:filter][:last_visit] = Date.parse(date.to_s).all_day
      #     super(:@leads_by_day, @substrate, :tracking_url)
      #     @stats_by[date.to_s] = {
      #       site_visits: site_visits(@leads_by_day),
      #       leads: leads(@leads_by_day),
      #       applications: applications(@leads_by_day),
      #       not_finished_applications: not_finished_applications(@leads_by_day),
      #       conversions: conversions(@leads),
      #       visitors: visitors(@leads_by_day),
      #       customers: customers(@leads_by_day)
      #     }
      #   end
      # else
      #   while start_date < end_date
      #     params[:filter][:last_visit] = start_date.all_month
      #     super(:@leads_by_month, @substrate, :tracking_url)
      #     @stats_by[start_date.end_of_month.to_s] = {
      #       site_visits: site_visits(@leads_by_month),
      #       leads: leads(@leads_by_month),
      #       applications: applications(@leads_by_month),
      #       not_finished_applications: not_finished_applications(@leads_by_month),
      #       conversions: conversions(@leads),
      #       visitors: visitors(@leads_by_month),
      #       customers: customers(@leads_by_month)
      #     }
      #     start_date += 1.month
      #   end
      # end
      #
      # render 'v2/shared/leads/dashboard_index'
      render json: {
        message: "Currently Unavailable: Under Construction"
      }, status: :ok
    end
  end
end
