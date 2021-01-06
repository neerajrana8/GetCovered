module V2
  module StaffAgency
    class LeadsController < StaffAgencyController

      before_action :set_substrate, only: :index
      before_action :set_lead, only: [:update, :show]

      def index
        super(:@leads, @substrate)
        render 'v2/shared/leads/index'
      end

      def show
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

        #need to remove after update on ui
        permitted = params.require(:lead).permit( :status)
        permitted[:archived] = permitted[:status] == 'archived' ? true : false
        permitted.delete(:status)

        permitted
      end

      def set_substrate
        if @substrate.nil?
          @substrate = access_model(::Lead).presented.not_converted.includes(:profile, :tracking_url)
          #need to delete after fix on ui
          if params[:filter].present? && params[:filter][:archived]
            @substrate = access_model(::Lead).presented.not_converted.archived.includes(:profile, :tracking_url)
          elsif params[:filter].nil? || !!params[:filter][:archived]
            @substrate = access_model(::Lead).presented.not_converted.not_archived.includes(:profile, :tracking_url)
          end
        end
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
            created_at: [:scalar, :array, :interval],
            email: [:scalar, :like],
            agency_id: [:scalar, :interval],
            status: [:scalar],
            archived: [:scalar]
        }
      end

      def supported_orders
        supported_filters(true)
      end

      def update_allowed?
        true
      end
    end
  end
end
