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
          end

        if @lead.nil?
          @lead = Lead.create(lead_params)
        else
          @lead.update(lead_params)
        end
      end

      def lead_params
        params.permit(%i[email identifier])
      end

      def event_params
        params.require(:lead_event_attributes).permit(:tag, :latitude, :longitude, :data).permit!
      end
    end
  end
end
