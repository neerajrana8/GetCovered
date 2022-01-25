##
# V2 StaffAgency Controller
# File: app/controllers/v2/staff_agency_controller.rb

module V2
  class StaffAgencyController < V2Controller
    before_action :authenticate_staff!
    before_action :is_agent?
    before_action :set_agency

    def set_agency
      agency_id = params[:agency_id]&.to_i
      @agency =
        if agency_id.blank?
          current_staff.current_role(organizable: 'Agency').organizable
        elsif current_staff.getcovered_agent?
          Agency.find(agency_id)
        elsif current_staff.agencies.ids.include?(agency_id)
          current_staff.agencies.find(agency_id)
        else
          current_staff.current_role(organizable: 'Agency').organizable
        end
    end

    private

    def self.check_privileges(args)
      if args.is_a?(String)
        before_action do
          validate_permission(args)
        end
      elsif args.is_a?(Array)
        before_action do
          validate_permissions(args)
        end
      elsif args.is_a?(Hash)
        args.each do |key, actions|
          before_action only: actions do
            validate_permission(key) if key.is_a?(String)
            validate_permissions(key) if key.is_a?(Array)
          end
        end
      end
    end

    def validate_permission(permission)
      if current_staff.staff_roles
        permitted = current_staff.current_role(organizable: 'Agency').global_permission.permissions[permission]
      else
        permitted = current_staff.staff_permission.permissions[permission]
      end

      render(json: standard_error(:permission_not_enabled), status: :unauthorized) unless permitted
    end

    def validate_permissions(permissions)
      if current_staff.staff_roles
        permitted = current_staff.current_role(organizable: 'Agency').global_permission.permissions.values_at(*permissions).include?(true)
      else
        permitted = current_staff.staff_permission.permissions.values_at(*permissions).include?(true)
      end

      render(json: standard_error(:permission_not_enabled), status: :unauthorized) unless permitted
    end

    def is_agent?
      render json: {error: 'Unauthorized access'}, status: :unauthorized unless current_staff.current_role(organizable: 'Agency').agent?
    end

    def view_path
      super + '/staff_agency'
    end

    def access_model(model_class, model_id = nil)
      @agency ||= current_staff.current_role(organizable: 'Agency')
      return @agency if model_class == ::Agency && model_id&.to_i == current_staff.current_role(organizable: 'Agency').organizable_id

      begin
        return @agency.send(model_class.name.underscore.pluralize).send(*(model_id.nil? ? [:itself] : [:find, model_id]))
      rescue StandardError
        nil
      end
    end
  end
end
