# Agencies Controller
module V2
  module Agencies
    class AgenciesController < V2::ApiController
      before_action :authenticate_staff!
      before_action :check_permissions

      def filter
        agencies = Agency.where(agency_id: nil)
        children = []
        per = 10
        page = 1

        # Permitted selection
        agencies_ids = current_staff.organizable.accounts if current_staff.role == :agent.to_s
        agencies_ids = current_staff.organizable.id if current_staff.role == :staff.to_s

        agencies = agencies.where(id: agencies_ids) if %(staff, agent).include?(current_staff.role)

        # Filtering
        if params[:filter].present?
          agencies = agencies.where(agency_id: params[:filter][:agency_id]) if params[:filter][:agency_id].present?
          agencies = agencies.title_like(params[:filter][:title]) if params[:filter][:title].present?
          children = Agency.where(agency_id: agencies.pluck(:id)) if params[:filter][:include_children].present?
        end

        # Sorting

        if params[:sort].present?
          agencies = agencies.order(title: params[:sort].to_sym)
        end

        # Pagination
        if params[:pagination].present?
          page = params[:pagination][:page] if params[:pagination][:page]
          per = params[:pagination][:per] if params[:pagination][:per]
        end

        agencies = agencies.page(page).per(per)

        @agencies = agencies + children
        render 'v2/agencies/agencies/filter'
      end

      private

      def check_permissions
        if current_staff && %(super_admin, staff, agent).include?(current_staff.role)
          true
        else
          render json: { error: 'Permission denied' }, status: 403
        end
      end
    end
  end
end
