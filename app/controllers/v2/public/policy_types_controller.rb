##
# V2 Policy Types Controller
# File: app/controllers/v2/public/policy_types_controller.rb

module V2
  module Public
    class PolicyTypesController < PublicController
      include PolicyTypesMethods     
    end
  end
end
