module V2
  module StaffAgency
    class LeadsController < StaffAgencyController

      def index
        super(:@leads, access_model(::Lead).includes(:profile, :tracking_url))
        render 'v2/shared/leads/index'
      end

      def show
        @lead = access_model(::Lead, params[:id])
        render 'v2/shared/leads/show'
      end
    end
  end
end
