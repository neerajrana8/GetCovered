##
# V2 Policy Types Controller
# File: app/controllers/v2/public/policy_types_controller.rb

module V2
  module Public
    class PolicyTypesController < PublicController
	  
      def index
        @policy_types = PolicyType.where(enabled: true)
        render :index, status: :ok                                           
		  end
	   
	  end
	end
end