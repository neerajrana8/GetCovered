##
# V2 Sdk PolicyApplications Controller
# File: app/controllers/v2/sdk/policy_applications_controller.rb
require 'securerandom'

module V2
  module Sdk
    class PolicyApplicationsController < SdkController
      include PolicyApplicationMethods

      def create_and_redirect
        puts params[:redirect_url]
      end

      private

      def create_and_redirect_params
        params.require(:policy_application)
              .permit(:effective_date, :expiration_date, :policy_type_id, fields: [:monthly_rent, :guarantee-option])
      end

    end
  end
end
