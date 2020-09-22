module V2
  module Public
    class LeadEventsController < PublicController
      before_action :set_lead, only: :create

      def create
        if @lead.errors.any?
          render json: standard_error(:lead_creation_error, nil, @lead.errors.full_messages)
        else
          @lead.lead_events.create(event_params)
        end
        render template: 'v2/shared/leads/full' if %i[awsdev development].include?(Rails.env.to_sym)
      end

      private



      def set_lead
        @lead =
          if lead_params[:email].present?
            Lead.find_by_email(lead_params[:email])
          end

        if @lead.nil?
          @lead = Lead.create(lead_params)
          Address.create(lead_address_attributes.merge(addressable: @lead)) if lead_address_attributes
          Profile.create(lead_profile_attributes.merge(profileable: @lead)) if lead_profile_attributes
        else
          nested_params = {}
          nested_params[:profile_attributes] = lead_profile_attributes if lead_profile_attributes
          nested_params[:address_attributes] = lead_address_attributes if lead_address_attributes
          @lead.update(lead_params.merge(nested_params))
        end
      end

      def lead_params
        params.permit(:email, :identifier)
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
          params.require(:address_attributes).permit(%i[city country state street_name street_two zip_code])
        end
      end

      def event_params
        data = params[:lead_event_attributes].delete(:data) if params[:lead_event_attributes][:data]
        params.require(:lead_event_attributes).permit(:tag, :latitude, :longitude, :agency_id, :policy_type_id).tap do |whitelisted|
          whitelisted[:data] = data.permit!
        end
      end
    end
  end
end
