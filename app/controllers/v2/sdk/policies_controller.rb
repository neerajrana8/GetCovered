##
# V2 Sdk PolicyApplications Controller
# File: app/controllers/v2/sdk/policies_controller.rb
require 'securerandom'

module V2
  module Sdk
    class PoliciesController < SdkController
      before_action :set_policy, only: [:show, :cancel]

      def index
        super(:@policies, @bearer.policies, :agency, :account, :primary_user, :primary_insurable, :carrier, :policy_type)
      end

      def show; end

      def cancel; end

      private

      def set_policy
        @policy = @bearer.policies.find_by_number(params[:number])
      end

    end
  end
end
