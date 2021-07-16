##
# V2 Sdk PolicyApplications Controller
# File: app/controllers/v2/sdk/policy_applications_controller.rb
require 'securerandom'

module V2
  module Sdk
    class PolicyApplicationsController < SdkController
      include PolicyApplicationMethods

      def create_and_redirect
        @app = @bearer.policy_applications.new(create_and_redirect_params)

        CarrierPolicyType.where(policy_type_id: create_and_redirect_params[:policy_type_id]).each do |cpt|
          if @bearer.carriers.include?(cpt.carrier)
            @app.carrier = cpt.carrier
            break
          end
        end

        if create_and_redirect_params[:effective_date].blank?
          place_holder_date = Time.now + 1.day
          @app.effective_date = place_holder_date
          @app.expiration_date = place_holder_date + 1.year
        end

        render json: @app.to_json,
               status: :ok
      end

      private

      def create_and_redirect_params
        params.require(:policy_application)
              .permit(:effective_date, :expiration_date, :policy_type_id, fields: [:monthly_rent, :guarantee_option])
      end

    end
  end
end
