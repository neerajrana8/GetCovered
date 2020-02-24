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
        case params[:policy_application][:policy_type_id]
        when 1
          create_residential()
        when 4
          create_commercial()
        else
          render json: { 
                   title: "Policy Type not Recognized", 
                   message: "Policy Type is not residential or commercial.  Please select a supported Policy Type" 
                 }, status: 422
        end
      end
      
      def create_policy_users
        params[:policy_application][:policy_users_attributes].each_with_index do |policy_user, index|

          if User.where(email: policy_user[:user_attributes][:email]).exists?
            @user = User.find_by_email(policy_user[:user_attributes][:email])
            if @user.invitation_accepted_at.nil?
              @application.users << @user
            else
              puts "\n\nPolicy User: #{ policy_user[:user_attributes][:email] } has not accepted invitation\n\n"
  	          render json: {
    	          error: "User Account Exists",
    	          message: "A User has already signed up with this email address.  Please log in to complete your application"
  	          }.to_json,
  	          status: 401              
            end  
          else
            
            secure_tmp_password = SecureRandom.base64(12)
            @user = @application.policy_users.create!(
              spouse: policy_user[:spouse],
              user_attributes: {
                email: policy_user[:user_attributes][:email],
                password: secure_tmp_password,
                password_confirmation: secure_tmp_password,
                profile_attributes: {
					        first_name: policy_user[:user_attributes][:profile_attributes][:first_name], 
					        last_name: policy_user[:user_attributes][:profile_attributes][:last_name], 
					        job_title: policy_user[:user_attributes][:profile_attributes][:job_title], 
					      	contact_phone: policy_user[:user_attributes][:profile_attributes][:contact_phone], 
					      	birth_date: policy_user[:user_attributes][:profile_attributes][:birth_date]                  
                }
              }
            )
            
            @user.invite! if index == 0
            
          end
          
        end
      end
      
      def create_commercial
        
        @application = PolicyApplication.new(create_commercial_params) 
        @application.agency = Agency.where(master_agency: true).take 

				@application.billing_strategy = BillingStrategy.where(agency: @application.agency, 
				                                                      policy_type: @application.policy_type,
				                                                      title: 'Annually').take
		    
		    if @application.save
  		    create_policy_users()
  		    if @application.update(status: 'complete')
            # Commercial Application Saved
            
    		    @application.primary_user().invite!
            quote_attempt = @application.crum_quote()
            
  					if quote_attempt[:success] == true
  						
  						@application.primary_user().set_stripe_id()
  						
  						@quote = @application.policy_quotes.last
  						@quote.generate_invoices_for_term()
  						@premium = @quote.policy_premium
  						
  						response = { 
  							quote: { 
  								id: @quote.id, 
  								status: @quote.status, 
  								premium: @premium
  							},
  							invoices: @quote.invoices,
  							user: { 
  								id: @application.primary_user().id,
  								stripe_id: @application.primary_user().stripe_id
  							},
  							billing_strategies: []
  						}
  						
  						if @premium.base >= 500000
  							BillingStrategy.where(agency: @application.agency_id, policy_type: @application.policy_type).each do |bs|
  							  response[:billing_strategies]	<< { id: bs.id, title: bs.title }
                end
  						end
  							  
  						render json: response.to_json, status: 200
  																
  					else
  						render json: { error: "Quote Failed", message: quote_attempt[:message] },
  									 status: 500							
  					end
					else
            render json: @application.errors.to_json,
                   status: 422					
					end			  		  
  		  else         
          
          # Commercial Application Save Error
          render json: @application.errors.to_json,
                 status: 422
        
        end       
      end
      
      def create_residential
        
        @application = PolicyApplication.new(create_residential_params)
        
        if @application.agency.nil? && 
	         @application.account.nil?
	         
	        @application.agency = Agency.where(master_agency: true).take 
	      elsif @application.agency.nil?
	      
          @application.agency = @application.account.agency  
        end
	      
	      if @application.save
  	      create_policy_users()
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
  								invoices: @quote.invoices.order('due_date ASC'),
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
	          render json: @application.errors.to_json,
	                 status: 422	
          end
  	    else
          render json: @application.errors.to_json,
                 status: 422   
  	    end
      end
      
      
      def update
        if @policy_application.policy_type.title == "Residential"
          
          if update_params.has_key?("policy_rates_attributes")
            
            new_rates = update_params["policy_rates_attributes"].map { |r| r["insurable_rate_id"] }
            current_rates = @policy_application.policy_rates.map(&:insurable_rate_id)
            
            @policy_application.policy_rates.each { |r| r.destroy if !new_rates.include?( r.insurable_rate_id ) || r.insurable_rate.sub_schedule == "policy_fee" }
            new_rates.each { |r| @application.insurable_rates << InsurableRate.find(r) if !current_rates.include?(r) }
            
            @policy_application.qbe_estimate()
            
          end
          
        else
        
        end
      end
      
      
      private
	      
	      def view_path
	        super + '/policy_applications'
	      end
	        
	      def set_policy_application
	        @policy_application = access_model(::PolicyApplication, params[:id])
	      end
	      
	      def create_residential_params
  	      params.require(:policy_application)
  	            .permit(:effective_date, :expiration_date, :fields, :auto_pay, 
		      							:auto_renew, :billing_strategy_id, :account_id, :policy_type_id,
		      							:carrier_id, :agency_id, fields: [:title, :value, options: []], 
		      							questions: [:title, :value, options: []], 
	                      policy_rates_attributes: [:insurable_rate_id],
	                      policy_insurables_attributes: [:insurable_id]) 
  	    end
	      
	      def create_commercial_params
  	      params.require(:policy_application)
  	            .permit(:effective_date, :expiration_date, :fields, :auto_pay, 
		      							:auto_renew, :billing_strategy_id, :account_id, :policy_type_id, 
		      							:carrier_id, :agency_id, fields: {}, 
		      							questions: [:text, :value, :questionId, options: [], questions: [:text, :value, :questionId, options: []]])  
  	    end
  	    
  	    def create_policy_users_params
    	    params.require(:policy_application)
    	          .permit(policy_users_attributes: [
			      							:spouse, user_attributes: [
				      							:email, profile_attributes: [
					      							:first_name, :last_name, :job_title, 
					      							:contact_phone, :birth_date	
				      							]
			      							]
			      					  ])  
    	  end
	      
	      def update_params
  	      params.require(:policy_application)
  	           .permit(policy_rates_attributes: [:insurable_rate_id],
  	                   policy_insurables_attributes: [:insurable_id])  
  	    end
	        
	      def valid_policy_types
	        %w[residential commercial]
	      end
        
    end
  end # module Public
end
