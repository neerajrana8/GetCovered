##
# V2 Sdk PolicyApplications Controller
# File: app/controllers/v2/sdk/policy_applications_controller.rb
require 'securerandom'

module V2
  module Sdk
    class PolicyApplicationsController < SdkController
      include PolicyApplicationMethods

    end
  end
end
