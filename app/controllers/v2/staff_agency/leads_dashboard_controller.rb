module V2
  module StaffAgency
    class LeadsDashboardController < StaffAgencyController

      include Leads::LeadsDashboardCalculations

      before_action :set_substrate, only: :index
      check_privileges 'dashboard.leads'

      def index
        start_date = Date.parse(date_params[:start])
        end_date   = Date.parse(date_params[:end])

        if date_params[:start] == date_params[:end]
          params[:filter][:last_visit] = start_date.all_day
        else
          params[:filter][:last_visit] = (start_date.all_day.first..end_date.all_day.last)
        end

        #check duplicates in totals?
        super(:@leads, @substrate, :profile, :tracking_url)

        @stats = {site_visits: site_visits(@leads), leads: leads(@leads), applications: applications(@leads),
                  not_finished_applications: not_finished_applications(@leads), conversions: conversions(@leads)}
        @stats_by = {}

        if filter_by_day?(start_date, end_date)
          start_date.upto(end_date) do |date|
            params[:filter][:last_visit] = Date.parse("#{date}").all_day
            super(:@leads_by_day, @substrate, :profile, :tracking_url)
            @stats_by["#{date}"] = {site_visits: site_visits(@leads_by_day), leads: leads(@leads_by_day), applications: applications(@leads_by_day),
                                    not_finished_applications: not_finished_applications(@leads_by_day), conversions: conversions(@leads_by_day)}
          end

        else
          while start_date < end_date
            params[:filter][:last_visit] = start_date.all_month
            super(:@leads_by_month, @substrate, :profile, :tracking_url)
            @stats_by["#{start_date.end_of_month}"] = {site_visits: site_visits(@leads_by_month), leads: leads(@leads_by_month), applications: applications(@leads_by_month),
                                                       not_finished_applications: not_finished_applications(@leads_by_month), conversions: conversions(@leads_by_month)}
            start_date += 1.month
          end
        end

        render 'v2/shared/leads/dashboard_index'
      end

      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::Lead).presented.not_archived.includes(:profile, :tracking_url)
        end
      end

    end
  end
end
