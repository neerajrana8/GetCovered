##
# V2 StaffAgency Controller
# File: app/controllers/v2/staff_agency_controller.rb

module V2
  class StaffAgencyController < V2Controller
    before_action :authenticate_staff!
    before_action :is_agent?
    before_action :set_agency

    def set_agency
      subagency_id = params[:agency_id]&.to_i
      @agency =
        if subagency_id.blank?
          current_staff.organizable
        else
          if current_staff.organizable.agencies.ids.include?(subagency_id)
            current_staff.organizable.agencies.find(subagency_id)
          else
            current_staff.organizable
          end
        end
    end

    private

    def is_agent?
      render json: { error: 'Unauthorized access' }, status: :unauthorized unless current_staff.agent?
    end

    def view_path
      super + '/staff_agency'
    end

    def access_model(model_class, model_id = nil)
      @agency ||= current_staff.organizable
      return @agency if model_class == ::Agency && model_id&.to_i == current_staff.organizable_id

      begin
        return @agency.send(model_class.name.underscore.pluralize).send(*(model_id.nil? ? [:itself] : [:find, model_id]))
      rescue StandardError
        nil
      end
    end
  end
end
