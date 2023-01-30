

module V2
  class StaffReportingController < V2Controller
    before_action :authenticate_staff!
    before_action :set_organizable

    def set_organizable
      @organizable = :NONE
      organizable_class = [Account, Agency].find{|c| c.name == params[:organizable_type] }
      organizable_id = params[:organizable_id].to_i
      @organizable =
        if current_staff.getcovered_agent?
          if organizable_class.nil?
            :EMPEROR
          else
            organizable_class.find(organizable_id)
          end
        else
          if organizable_class == Agency && current_staff.organizable_type == "Agency" && current_staff.organizable.agencies.ids.include?(organizable_id)
            organizable_class.find(organizable_id)
          else
            current_staff.organizable
          end
        end
      # for robust security, just in case it's somehow nil when it shouldn't be we set it to :NONE; for query convenience we want it to be nil for superadmin access
      if @organizable.nil?
        @organizable = :NONE
      elsif @organizable == :EMPEROR
        @organizable = nil
      end
    end
    
    def access_model(model_class, model_id = nil)
      return (@organizable.nil? ? model_class : @organizable.send(model_class.name.split("::").map{|x| x.underscore.pluralize }.join("_"))).send(*(model_id.nil? ? [:itself] : [:find, model_id])) rescue nil
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
            validate_permission(key)  if key.is_a?(String)
            validate_permissions(key) if key.is_a?(Array)
          end
        end
      end
    end

    def validate_permission(permission)
      permitted = current_staff.staff_permission.permissions[permission]
      render(json: standard_error(:permission_not_enabled), status: :unauthorized) unless permitted
    end

    def validate_permissions(permissions)
      permitted = current_staff.staff_permission.permissions.values_at(*permissions).include?(true)
      render(json: standard_error(:permission_not_enabled), status: :unauthorized) unless permitted
    end

    def view_path
      super + '/staff_reporting'
    end

  end
end
