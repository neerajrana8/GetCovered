module Concerns
  module Leads
    module LeadsCreateMethods
      extend ActiveSupport::Concern

      private

      def create_lead_event
        track_status = @klaviyo_helper.process_events("New Lead Event", @lead) do
          @lead.lead_events.create(event_params)
        end
      end

      def set_lead(external_params = nil)
        initialize_klaviyo

        params.merge!(external_params) if external_params.present?

        @lead = if lead_params[:identifier].present?
                  Lead.find_by_identifier(lead_params[:identifier])
                elsif lead_params[:email].present?
                  Lead.find_by_email(lead_params[:email])
                end

        agency = Agency.find(params[:agency_id])
        tracking_url = TrackingUrl.find_by(landing_page: unescape_param(tracking_url_params["landing_page"]), campaign_source: unescape_param(tracking_url_params["campaign_source"]),
                                           campaign_medium: unescape_param(tracking_url_params["campaign_medium"]), campaign_term: unescape_param(tracking_url_params["campaign_term"]),
                                           campaign_content: unescape_param(tracking_url_params["campaign_content"]), campaign_name: unescape_param(tracking_url_params["campaign_name"]),
                                           branding_profile_id: tracking_url_params["branding_profile_id"]) if tracking_url_params.present?

        @klaviyo_helper.lead = @lead if @lead.present?

        if @lead.nil?
          track_status = @klaviyo_helper.process_events("New Lead") do
            create_params = lead_params
            create_params.merge({tracking_url_id: tracking_url.id}) if tracking_url.present?
            create_params.merge({agency_id: agency.id}) if agency.present?

            begin
              @lead = Lead.create(create_params)
            rescue ActiveRecord::RecordNotUnique
              @lead = Lead.find_by_identifier(lead_params[:email])
              # @lead = if lead_params[:identifier].present?
              #   Lead.find_by_identifier(lead_params[:identifier])
              # elsif lead_params[:email].present?
              #   Lead.find_by_email(lead_params[:email])
              # end
            end

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
        permitted = params.permit(:email, :identifier, :last_visited_page, :agency_id, :account_id, :branding_profile_id)
        permitted[:email] = permitted[:email].downcase
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
                        permit(:tag, :latitude, :longitude, :agency_id, :account_id, :policy_type_id, :branding_profile_id).tap do |whitelisted|
          whitelisted[:data] = data.permit!
        end
      end

      def tracking_url_params
        if params[:tracking_url].present?
          params.
            require(:tracking_url).
            permit(%i[landing_page campaign_source campaign_medium campaign_term campaign_content campaign_name branding_profile_id])
        end
      end

      def external_api_call_params(application)
        user_attr = create_policy_users_params[:policy_users_attributes].first[:user_attributes]
        user_attr[:email] = user_attr[:email].downcase
        request = {
          "email": user_attr[:email],
                   "lead_event_attributes":{
                          "tag":"",
                          "data":{
                "unit": residential_address_params[:fields][:unit],
                                  "unit_na":false,
                                  "effective_date": application.effective_date.to_s,
                                  "expiration_date": application.expiration_date.to_s,
                                  "number_of_insured": 1,
                                  "billing_strategy_id": application.billing_strategy_id,
                                  "deductible":"",
                                  "deductible_fl":"",
                                  "email": user_attr[:email],
                                  "contact_phone": user_attr[:profile_attributes][:contact_phone],
                                  "suite_unit":"",
                                  "insured_user_arr":[

                                  ],
                                  "community_details":{
                                     "number_of_units":"",
                                     "gated":"",
                                     "year_built":"",
                                     "years_professionally_managed":""
                                   },
                                  "address": residential_address_params[:fields][:address],
                                  "policy_type_id": application.policy_type_id,
                                  "last_visited_page": application.policy_type_id==1 ? "Basic Info Section" : "Landing Page"
              }
                        },
                   "profile_attributes":{
                       "first_name": user_attr[:profile_attributes][:first_name],
                                         "last_name": user_attr[:profile_attributes][:last_name],
                                         "birth_date": Date.parse(user_attr[:profile_attributes][:birth_date] ).to_s,
                                         "contact_phone": user_attr[:profile_attributes][:contact_phone]
                     },
                   "address_attributes":{
                       "street_name": residential_address_params[:fields][:address]
                     },
                   "policy_type_id": application.policy_type_id,
                   "agency_id": application.agency_id
        }
      end

      def escape_param(value)
        value.nil? ? value : CGI::escape(value)
      end

      def unescape_param(value)
        value.nil? ? value : CGI::unescape(value)
      end

    end
  end
end
