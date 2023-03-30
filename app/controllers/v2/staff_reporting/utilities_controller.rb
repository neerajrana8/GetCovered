


module V2
  module StaffReporting
    class UtilitiesController < StaffReportingController
    
      def auth_check # accessible only if user is logged in; used to check if stored login creds are still working
        render json: { success: true },
          status: :ok
      end
      
      def owner_list # returns a list of viable report owners, i.e. identities for a gc agent to masquerade as
        render json: [{ type: nil, id: nil, title: "ADMIN" }] +
          ::Account.where(id: Reporting::CoverageReport.where(status: 'ready', owner_type: 'Account').select(:owner_id))
                   .order(title: :asc)
                   .pluck(:id, :title)
                   .map{|a| { type: 'Account', id: a[0], title: a[1] } }
                   .to_a,
          status: :ok
      end
      
    end
  end
end
