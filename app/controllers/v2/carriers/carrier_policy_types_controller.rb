module V2
  module Carriers
    class CarrierPolicyTypesController < V2::ApiController
      include ActionController::Caching

      before_action :authenticate_staff!
      before_action :check_permissions

      def list
        filter = {}
        filter = params[:filter] if params[:filter].present?
        @carrier_policy_types = []
        @meta = {}
        @carrier_policy_types = CarrierPolicyType.where(carrier_id: filter[:carrier_id]) if filter[:carrier_id].present?
        render 'v2/carriers/carrier_policy_types/list'
      end

      private

      def check_permissions
        if current_staff && %(super_admin).include?(current_staff.role)
          true
        else
          render json: { error: 'Permission denied' }, status: 403
        end
      end

    end
  end
end
