module V2
  module StaffSuperAdmin
    class LeadsController < StaffSuperAdminController
      include ActionController::MimeResponds
      include Leads::LeadsRecentMethods

      before_action :set_lead, only: %i[update show]
      before_action :set_substrate, only: :index


      def show
        @visits = @lead.lead_events.order('DATE(created_at)').group('DATE(created_at)').count.keys.size
        @last_premium_estimation =
          @lead.lead_events.where("(data -> 'total_amount') is not null").order(created_at: :desc).first
        render 'v2/shared/leads/show'
      end

      def update
        if update_allowed?
          if @lead.update_as(current_staff, update_params)
            render 'v2/shared/leads/show', status: :ok
          else
            render json: @lead.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: [I18n.t('user_users_controler.unauthorized_access')] },
                 status: :unauthorized
        end
      end

      private

      def set_lead
        @lead = access_model(::Lead, params[:id])
      end

      def update_params
        return({}) if params[:lead].blank?

        params.require(:lead).permit(:archived)
      end

      def set_substrate
        if @substrate.nil?
          @substrate = access_model(::Lead).presented.not_converted.includes(:profile, :tracking_url).preload(:lead_events)
          # need to delete after fix on ui
          # if params[:filter].present? && params[:filter][:archived]
          #  @substrate = access_model(::Lead).presented.not_converted.archived.includes(:profile, :tracking_url)
          # elsif params[:filter].nil? || !!params[:filter][:archived]
          #  @substrate = access_model(::Lead).presented.not_converted.not_archived.includes(:profile, :tracking_url)
          # end
        end
      end

      def update_allowed?
        true
      end

    end
  end
end
