##
# V2 Sdk PolicyApplications Controller
# File: app/controllers/v2/sdk/policy_applications_controller.rb
require 'securerandom'

module V2
  module Sdk
    class PolicyApplicationsController < SdkController
      include PolicyApplicationMethods

      def create
        site = @bearer.branding_profiles.count > 0 ? "https://#{@bearer.branding_profiles.where(default: true).take.url}" :
                 Rails.application.credentials[:uri][Rails.env.to_sym][:client]

        init_hash = {
          carrier_id: 1,
          policy_type_id: 1,
          account_id: @bearer.is_a?(Agency) ? nil : @bearer.id,
          agency_id: @bearer.is_a?(Agency) ? @bearer.id : @bearer.agency_id,
          effective_date: create_policy_application_params[:effective_date],
          expiration_date: create_policy_application_params[:effective_date].to_date + 1.year,
          fields: create_policy_application_params[:fields]
        }

        @application = PolicyApplication.new(init_hash)
        @application.build_from_carrier_policy_type
        @application.billing_strategy = BillingStrategy.where(agency:       @application.agency,
                                                              policy_type:  @application.policy_type,
                                                              carrier:      @application.carrier).take

        if create_policy_application_params[:fields].has_key?(:unit_id)
          @application.policy_insurables_attributes = [{ primary: true,
                                                         insurable_id: create_policy_application_params[:fields][:unit_id],
                                                         policy_id: nil }]
        end

        if @application.save
          # update users
          update_users_result =
            PolicyApplications::UpdateUsers.run!(
              policy_application: @application,
              policy_users_params: create_policy_users_params[:policy_users_attributes]
            )
          if update_users_result.success?
            if @application.update(status: 'in_progress')
              # get token and redirect url
              new_access_token = @application.create_access_token
              @redirect_url = "#{site}/residential/#{new_access_token.to_urlparam}#{ @bearer.is_a?(Account) ? "?access=iframe" : "" }"
              render 'v2/public/policy_applications/show_external'
            else
              render json: standard_error(:policy_application_update_error, nil, @application.errors),
                     status: 422
            end
          else
            render json: update_users_result.failure, status: 422
          end
        else
          # Rental Guarantee Application Save Error
          render json: standard_error(:policy_application_update_error, nil, @application.errors),
                 status: 422
        end
      end

      private

      def create_policy_application_params
        params.require(:policy_application)
              .permit(:effective_date, :policy_type_id,
                      fields: [:monthly_rent, :guarantee_option, :unit_id, :building_id, :community_id])
      end

      def create_policy_users_params
        params.require(:policy_application)
              .permit(policy_users_attributes: [
                :primary, :spouse, user_attributes: [
                  :email,
                  profile_attributes: [:first_name, :last_name, :middle_name,
                                       :job_title, :contact_phone, :birth_date,
                                       :gender, :salutation],
                  address_attributes: [:city, :country, :county, :id, :latitude,
                                       :longitude, :plus_four, :state, :street_name,
                                       :street_number, :street_two, :timezone, :zip_code]
                ]
              ])
      end

    end
  end
end
