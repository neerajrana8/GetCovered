module V2
  module Policies
    class PoliciesController < ApiController
      include ActionController::Caching

      before_action :authenticate_staff!
      before_action :check_permissions

      def list
        page = 1
        per = 50
        filter = {}
        filter = params[:filter] if params[:filter].present?

        # Permitted selection
        if current_staff.role == 'staff' && !current_staff.getcovered_agent?
          if current_staff.organizable_type == 'Account'
            filter[:account_id] = [current_staff.organizable.id]
          end
        end

        if current_staff.organizable_type == 'Agency'
          current_agency = Agency.find(current_staff.organizable_id)
          # We are root agency
          if current_agency.agency_id.nil? && filter[:agency_id].blank?
            sub_agencies_ids = []
            sub_agencies = current_agency.agencies
            sub_agencies_ids = sub_agencies.pluck(:id) if sub_agencies.count.positive?
            sub_agencies_ids << current_staff.organizable_id
            filter[:agency_id] = sub_agencies_ids
          end
          # We are sub agency
          filter[:agency_id] = [current_agency.id] unless current_agency.agency_id.nil?
        end

        filtering_keys = %i[policy_in_system agency_id status account_id policy_type_id number]
        params_slice ||= []
        params_slice = filter.slice(*filtering_keys)
        policies = Policy.filter(params_slice).includes(users: :profile).references(:profiles)

        # Profile fields filtering
        if filter[:users].present?
          payload = filter[:users]
          policies = policies.where('users.email LIKE ?', "%#{payload['email']['like']}%") if payload[:email].present?
          policies = policies.where('profiles.full_name LIKE ?', "%#{payload[:profile][:full_name][:like]}%") if payload[:profile].present?
          policies = policies.where(users: { id: payload[:id] }) if payload[:id].present?
        end

        if filter[:insurable_id].present?
          policies = policies.where(policy_insurables: { insurable_id: filter[:insurable_id] })
        end

        if params[:pagination].present?
          per = params[:pagination][:per] if params[:pagination][:per].present?
          page = params[:pagination][:page] if params[:pagination][:page].present?
        end

        policies = policies.order(created_at: :desc).page(page).per(per)

        if params[:sort].present?
          policies = policies.order(updated_at: params[:sort][:updated_at]) if params[:sort][:updated_at].present?
          policies = policies.order(created_at: params[:sort][:created_at]) if params[:sort][:created_at].present?
        end

        @policies = policies
        @meta = { total: policies.total_count, page: policies.current_page, per: per }
        render 'v2/policies/list'
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
