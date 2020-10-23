module V2
  module Public
    class LeadEventsController < PublicController

      before_action :set_lead, only: :create

      def create
        track_status = @klaviyo_helper.process_events("New Lead Event", @lead) do
          if @lead.errors.any?
            render json: standard_error(:lead_creation_error, nil, @lead.errors.full_messages)
          else
            @lead.lead_events.create(event_params)
            render template: 'v2/shared/leads/full'
          end
        end
      end

      private

      def set_lead
        initialize_klaviyo

        @lead = if lead_params[:identifier].present?
                  Lead.find_by_identifier(lead_params[:identifier])
                elsif lead_params[:email].present?
                  Lead.find_by_email(lead_params[:email])
                end

        tracking_url = TrackingUrl.find_by(tracking_url: params[:tracking_url])

        @klaviyo_helper.lead = @lead if @lead.present?

        if @lead.nil?
          track_status = @klaviyo_helper.process_events("New Lead") do
            create_params = lead_params.merge(environment: ENV["RAILS_ENV"])
            create_params.merge({tracking_url_id: tracking_url.id}) if tracking_url.present?
            @lead = Lead.create(create_params)
            Address.create(lead_address_attributes.merge(addressable: @lead)) if lead_address_attributes
            Profile.create(lead_profile_attributes.merge(profileable: @lead)) if lead_profile_attributes
            @klaviyo_helper.lead = @lead
          end

        else

          #need to resolve when come again and profile started to update from fill to blank
          nested_params = {}
          nested_params[:profile_attributes] = lead_profile_attributes if lead_profile_attributes
          nested_params[:address_attributes] = lead_address_attributes if lead_address_attributes
          nested_params[:tracking_url_id] = tracking_url.id if tracking_url.present?

          if lead_params[:email] != @lead.email
            track_status = @klaviyo_helper.process_events("Updated Email", {email: @lead.email, new_email: lead_params[:email]}) do
              @lead.update(email: lead_params[:email])
            end
          end

          track_status = @klaviyo_helper.process_events("Became Lead", nested_params) do
            @lead.update(nested_params) if nested_params.present?
          end
        end
      end

      def initialize_klaviyo
        @klaviyo_helper ||= KlaviyoService.new
      end

      def lead_params
        params.permit(:email, :identifier, :last_visited_page) #:agency_id
      end

      def lead_profile_attributes
        if params[:profile_attributes].present?
          params.
              require(:profile_attributes).
              permit(%i[birth_date contact_phone first_name gender job_title middle_name last_name salutation])
        end
      end

      def lead_address_attributes
        if params[:address_attributes].present?
          params.
              require(:address_attributes).
              permit(%i[city country state street_name street_two zip_code])
        end
      end

      # TODO : need to remove agency_id from event and move on ui to lead obj
      def event_params
        data = params[:lead_event_attributes].delete(:data) if params[:lead_event_attributes][:data]
        params.
            require(:lead_event_attributes).
            permit(:tag, :latitude, :longitude, :agency_id, :policy_type_id).tap do |whitelisted|
          whitelisted[:data] = data.permit!
        end
      end

    end
  end
end
