module V2
  module StaffSuperAdmin
    class LeadsDashboardController < StaffSuperAdminController
      include Leads::LeadsDashboardMethods

      before_action :set_substrate, only: :index

      def set_substrate
        @substrate = access_model(::Lead).presented.not_converted.includes(:profile, :tracking_url).preload(:lead_events)
      end

      def get_filters
        data = {}
        %i[campaign_source campaign_name campaign_medium].each do |k|
          data[k] = TrackingUrl.not_deleted.pluck(k).uniq.compact
        end
        render json: data
      end
    end
  end
end
