module Leads
  module LeadsDashboardCalculations
    extend ActiveSupport::Concern

    MAX_COUNTS = 9998

    def get_filters
      render json: {
        campaign_source: TrackingUrl.not_deleted.pluck(:campaign_source).uniq.compact.reject { |el| el == '' }.as_json,
        campaign_name: TrackingUrl.not_deleted.pluck(:campaign_name).uniq.compact.reject { |el| el == '' }.as_json,
        campaign_medium: TrackingUrl.not_deleted.pluck(:campaign_medium).uniq.compact.reject { |el| el == '' }.as_json
      }
    end

    def supported_filters(called_from_orders = false)
      @calling_supported_orders = called_from_orders
      {
        agency_id: %i[scalar array],
        agency: %i[scalar array],
        account_id: %i[scalar array],
        last_visit: %i[interval scalar],
        tracking_url: {
          campaign_source: [:scalar],
          campaign_medium: [:scalar],
          campaign_name: [:scalar]
        },
        branding_profile_id: %i[scalar array],
        branding_profile: {
          url: %i[scalar like]
        },
        lead_events: {
            policy_type_id: %i[scalar array],
          policy_type: %i[scalar array]
        }
      }
    end

    def supported_orders
      supported_filters(true)
    end

    def default_pagination_per
      MAX_COUNTS
    end

    def maximum_pagination_per
      MAX_COUNTS
    end

    private

    def filter_by_day?(start_date, end_date)
      (((end_date - 1.month) == start_date) || ((end_date - 1.week) == start_date)) || (end_date.mjd - start_date.mjd < 31)
    end

    # data for last_month or last_year of from the begining of the year
    def filter_by_month?(start_date, end_date)
      ((end_date - 1.year) == start_date) || (start_date == end_date.beginning_of_year) || (end_date.mjd - start_date.mjd > 31)
    end

    # need to refactor
    def site_visits(leads)
      return 0
      visits = 0
      leads.each do |lead|
        visits += lead.lead_events.order('DATE(created_at)').group('DATE(created_at)').count.keys.size
      end
      visits
    end

    def leads(leads)
      # leads.where(last_visited_page: [Lead::PAGES_RENT_GUARANTEE[0], Lead::PAGES_RESIDENTIAL[0]]).count
      leads.not_converted.count
    end

    def customers(leads)
      leads.converted.count
    end

    def visitors(leads)
      leads.count
    end

    def applications(leads)
      leads.not_converted.where.not(last_visited_page: [Lead::PAGES_RENT_GUARANTEE[0], Lead::PAGES_RESIDENTIAL[0]]).count
    end

    def not_finished_applications(leads)
      leads.not_converted.where(last_visited_page: [Lead::PAGES_RENT_GUARANTEE.last, Lead::PAGES_RESIDENTIAL.last]).count
    end

    def conversions(leads)
      leads.converted.
        joins(user: :policies).
        where(policies: { created_at: params[:filter][:last_visit] }).
        count
    end

    # need to add validation
    def date_params
      if params[:filter].present?
        {
          start: params[:filter][:last_visit][:start],
          end: params[:filter][:last_visit][:end]
        }
      else
        params[:filter] = {}
        {
          start: Lead.date_of_first_lead || Time.now.beginning_of_year,
          end: Time.now
        }
      end
    end
  end
end
