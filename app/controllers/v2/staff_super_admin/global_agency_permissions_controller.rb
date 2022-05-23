module V2
  module StaffSuperAdmin
    class GlobalAgencyPermissionsController < StaffSuperAdminController

      def available_permissions
        @available_permissions = GlobalPermission::AVAILABLE_PERMISSIONS
        render template: 'v2/shared/global_agency_permissions/available_permissions', status: :ok
      end
    end
  end
end
