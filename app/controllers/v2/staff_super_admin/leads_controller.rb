module V2
  module StaffSuperAdmin
    class LeadsController < StaffSuperAdminController

      def index
        super(:@leads, Lead.includes(:profile))
        render 'v2/shared/leads/index'
      end

      def show
        @lead = access_model(::Lead, params[:id])
        render 'v2/shared/leads/show'
      end
    end
  end
end
