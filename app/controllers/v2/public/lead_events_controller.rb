#require 'lib/klaviyo/redis_client'

module V2
  module Public
    class LeadEventsController < PublicController

      before_action :set_lead, only: :create

      def create
          if @lead.errors.any?
            render json: standard_error(:lead_creation_error, nil, @lead.errors.full_messages)
          else
            track_status = @klaviyo_helper.process_events("New Lead Event", @lead) do
              @lead.lead_events.create(event_params)
            end
            render template: 'v2/shared/leads/full'
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

        agency = Agency.find(params[:agency_id])
        tracking_url = TrackingUrl.find_by(landing_page: tracking_url_params["landing_page"], campaign_source: tracking_url_params["campaign_source"],
                            campaign_medium: tracking_url_params["campaign_medium"], campaign_term: tracking_url_params["campaign_term"],
                            campaign_content: tracking_url_params["campaign_content"], campaign_name: tracking_url_params["campaign_name"],
                                           agency_id: agency.id) if tracking_url_params.present?

        @klaviyo_helper.lead = @lead if @lead.present?

        if @lead.nil?
          track_status = @klaviyo_helper.process_events("New Lead") do
            create_params = lead_params
            create_params.merge({tracking_url_id: tracking_url.id}) if tracking_url.present?
            create_params.merge({agency_id: agency.id}) if agency.present?

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
          nested_params[:agency_id] = agency.id if agency.present? && @lead.agency_id != agency.id

          @lead.check_identifier
          if @lead.email.present? && lead_params[:email].present? && lead_params[:email] != @lead.email
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
        permitted = params.permit(:email, :identifier, :last_visited_page, :agency_id)
        permitted[:last_visited_page] = params[:lead_event_attributes][:data][:last_visited_page] if params[:lead_event_attributes] &&
            params[:lead_event_attributes][:data] && permitted[:last_visited_page].blank?
        permitted
      end

      def lead_profile_attributes
        if params[:profile_attributes].present?
          permitted_params = params.
              require(:profile_attributes).
              permit(%i[birth_date contact_phone first_name gender job_title middle_name last_name salutation])
          if params[:lead_event_attributes].present? && params[:lead_event_attributes][:data].present?
            permitted_params[:contact_phone] = params[:lead_event_attributes][:data][:contact_phone] if params[:lead_event_attributes][:data][:contact_phone].present?
          end
        end
        permitted_params
      end

      def lead_address_attributes
        if params[:address_attributes].present?
          params.
              require(:address_attributes).
              permit(%i[city country state street_name street_two zip_code])
        end
      end

      def event_params
        data = params[:lead_event_attributes].delete(:data) if params[:lead_event_attributes][:data]
        if data.present?
          data[:policy_type_id] = params[:policy_type_id]
          data[:locale] = "#{I18n.locale}"
        else
          data = {policy_type_id: params[:policy_type_id]}
        end
        permitted ||= params.
            require(:lead_event_attributes).
            permit(:tag, :latitude, :longitude, :agency_id, :policy_type_id).tap do |whitelisted|
              whitelisted[:data] = data.permit!
        end
      end

      def tracking_url_params
        if params[:tracking_url].present?
          params.
              require(:tracking_url).
              permit(%i[landing_page campaign_source campaign_medium campaign_term campaign_content campaign_name])
        end
      end

    end
  end
end
