##
# V2 Public PolicyApplications Controller
# File: app/controllers/v2/public/policy_applications_controller.rb
require 'securerandom'

module V2
  module Public
    class PolicyApplicationsController < PublicController
      
      before_action :set_policy_application,
        only: %i[update show]
      
      def show
        if %w[started in_progress
              abandoned more_required].include?(@policy_application.status)
            
        else

          render json: { error: 'Policy Application is not found or no longer available' }.to_json,
                 status: 404
        end
      end
      
      def new
        selected_policy_type = params[:policy_type].blank? ? 'residential' : params[:policy_type]
        if valid_policy_types.include?(selected_policy_type)
          policy_type = PolicyType.find_by_slug(selected_policy_type)
          carrier = selected_policy_type == 'residential' ? Carrier.find(1) : Carrier.find(3)
          
          @application = PolicyApplication.new(policy_type: policy_type, carrier: carrier)
          @application.build_from_carrier_policy_type
          @primary_user = ::User.new
          @application.users << @primary_user
          
        else
          render json: { error: 'Invalid policy type' },
                 status: :unprocessable_entity
        end
      end
      
      def create
        @application = PolicyApplication.new(create_params)
        
        if @application.agency.nil?
          @application.agency = @application.account.agency  
        end
        
        @application.policy_users.each do |pu|
	        secure_tmp_password = SecureRandom.base64(12)
	        pu.user.password = secure_tmp_password
	        pu.user.password_confirmation = secure_tmp_password
	      end
        
        if @application.save
	        
	        if @application.policy_type.title == "Residential"
		        # if residential application
	        	if @application.update status: "complete"
		        	# if application.status updated to complete
		        	@application.qbe_estimate()
		        	@quote = @application.policy_quotes.last
							if @application.status != "quote_failed" || application.status != "quoted"
								# if application quote success or failure
								@application.qbe_quote(@quote.id) 
								@application.reload()
								@quote.reload()
								
								if @quote.status == "quoted"	
									
									@application.primary_user().set_stripe_id()
										 
									render json: { 
										quote: { 
											id: @quote.id, 
											status: @quote.status, 
											premium: @quote.policy_premium 
										},
										user: { 
											id: @application.primary_user().id,
											stripe_id: @application.primary_user().stripe_id
										}
									}.to_json, status: 200
								
								else
									render json: { error: "Quote Failed", message: "Quote could not be processed at this time" },
												 status: 500	
								end
							else
								render json: { error: "Application Unavailable", message: "Application cannot be quoted at this time" },
											 status: 400							
							end       	
		        else
							render json: { error: "Application Incomplete", message: "Application is incomplete and must be finished to proceed" },
										 status: 400		        
		        end
	        elsif @application.policy_type.title == "Commercial"
						quote_attempt = @application.crum_quote()
						if quote_attempt[:success] == true
							@quote = @application.policy_quotes.last
							render json: { quote: { id: @quote.id, status: @quote.status, premium: @quote.policy_premium },
										   			 user: { id: @application.primary_user().id, stripe_id: @application.primary_user().stripe_id }
										 			 }.to_json,
										 status: 200								
						else
							render json: { error: "Quote Failed", message: "Quote could not be processed at this time" },
										 status: 500							
						end	        
	        end
        else
          render json: @application.errors.to_json,
                 status: 400
        end
      end
      
      
      private
	      
	      def view_path
	        super + '/policy_applications'
	      end
	        
	      def set_policy_application
	        @policy_application = access_model(::PolicyApplication, params[:id])
	      end
	        
	      def create_params
		      params.require(:policy_application).permit!
	# 	      			.permit(:effective_date, :expiration_date, :fields, :auto_pay, 
	# 	      							:auto_renew, :billing_strategy_id, :account_id, 
	# 	      							:carrier_id, :agency_id, fields: {}, questions: [], 
	#                       policy_rates_attributes: [:insurable_rate_id],
	#                       policy_insurables_attributes: [:insurable_id],
	#                       policy_users_attributes: [
	# 		      							:spouse, user_attributes: [
	# 			      							:email, profile_attributes: [
	# 				      							:first_name, :last_name, :contact_phone, :birth_date	
	# 			      							]
	# 		      							]
	# 	      							])
	      end
	        
	      def valid_policy_types
	        %w[residential commercial]
	      end
        
    end
  end # module Public
end
