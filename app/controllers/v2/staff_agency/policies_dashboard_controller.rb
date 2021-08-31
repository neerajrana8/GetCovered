module V2
  module StaffAgency
    class PoliciesDashboardController < StaffAgencyController
      include ::PoliciesDashboardMethods

      private

      def recipient
        @agency
      end

      def all_policies
        if params[:filter][:policy_type_id].present?
          Policy.not_master.where(policy_type_id: params[:filter][:policy_type_id], agency: @agency)
        else
          Policy.not_master.where(agency: @agency)
        end
      end
    end
  end
end
