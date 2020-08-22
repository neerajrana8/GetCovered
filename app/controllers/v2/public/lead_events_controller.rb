module V2
  module Public
    class LeadEventsController < PublicController
      before_action :set_lead, only: :create

      def create
        @lead.lead_events.create(event_params)
      end

      private

      def set_lead
        @lead =
          if lead_params[:email].present?
            Lead.find_by_email(lead_params[:email])
          elsif lead_params[:identifier].present?
            Lead.find_by_identifier(lead_params[:identifier])
          else
            Lead.create(lead_params)
          end
      end

      def lead_params
        params.permit(%i[email identifier])
      end

      def event_params
        params.permit(lead_event_attributes: %i[data latitude longitude])
      end
    end
  end
end
