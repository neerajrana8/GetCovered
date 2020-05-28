##
# V2 Public PolicyApplications Controller
# File: app/controllers/v2/public/policy_applications_controller.rb
require 'securerandom'

module V2
  module Public
    class PolicyApplicationsController < PublicController
      
      before_action :set_policy_application,
        only: %i[update, show]
      
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
          
          if selected_policy_type == "residential"
            carrier_id = 1
          elsif selected_policy_type == "commercial"
            carrier_id = 3
          elsif selected_policy_type == "rent-guarantee"
            carrier_id = 4
          end
          
          carrier = Carrier.find(carrier_id)
          
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
        when 5
        	create_rental_guarantee()
        else
          render json: { 
                   title: "Policy Type not Recognized", 
                   message: "Policy Type is not residential or commercial.  Please select a supported Policy Type" 
                 }, status: 422
        end
      end
      
      def create_policy_users
        error_status = []
        params[:policy_application][:policy_users_attributes].each_with_index do |policy_user, index|

          if ::User.where(email: policy_user[:user_attributes][:email]).exists?
            
            @user = ::User.find_by_email(policy_user[:user_attributes][:email])
            
            if index == 0
              if @user.invitation_accepted_at? == false
                @application.users << @user
                error_status << false
              else
    	          render json: {
      	            error: "User Account Exists",
      	            message: "A User has already signed up with this email address.  Please log in to complete your application"
    	            }.to_json,
    	            status: 401 
    	          error_status << true           
              end                
            else
              @application.users << @user
            end
            
            if policy_user[:user_attributes][:address_attributes]
              if @user.address.nil?
                @user.create_address(
                  street_number: policy_user[:user_attributes][:address_attributes][:street_number],
                  street_name: policy_user[:user_attributes][:address_attributes][:street_name] ,
                  street_two: policy_user[:user_attributes][:address_attributes][:street_two],
                  city: policy_user[:user_attributes][:address_attributes][:city],
                  state: policy_user[:user_attributes][:address_attributes][:state],
                  country: policy_user[:user_attributes][:address_attributes][:country],
                  county: policy_user[:user_attributes][:address_attributes][:county],
                  zip_code: policy_user[:user_attributes][:address_attributes][:zip_code]
                )  
              else  
                tmp_full = policy_user[:user_attributes][:address_attributes].to_unsafe_h
                                                                             .map { |k,v|
                                                                               unless ['county', 'country'].include?(k) 
                                                                                 "#{ v }"
                                                                               end
                                                                             }
                                                                             .join(' ')
                                                                             .gsub(/\s+/, ' ')
                                                                             .gsub(/[^0-9a-z ]/i, '')
                                                                             .strip

                if @user.address.full_searchable != tmp_full
      	          render json: {
        	            error: "Address mismatch",
        	            message: "The mailing address associated with this email is different than the one supplied in the recent request.  To change your address please log in"
      	            }.to_json,
      	            status: 401 and return
      	          error_status << true   
                end        
              end
            end
          else
            secure_tmp_password = SecureRandom.base64(12)
						policy_user_params = {
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
						}
						if policy_user[:user_attributes][:address_attributes]
							policy_user_params[:user_attributes].merge!(
								address_attributes:{
									street_number: policy_user[:user_attributes][:address_attributes][:street_number],
									street_name: policy_user[:user_attributes][:address_attributes][:street_name] ,
									street_two: policy_user[:user_attributes][:address_attributes][:street_two],
									city: policy_user[:user_attributes][:address_attributes][:city],
									state: policy_user[:user_attributes][:address_attributes][:state],
									country: policy_user[:user_attributes][:address_attributes][:country],
									county: policy_user[:user_attributes][:address_attributes][:county],
									zip_code: policy_user[:user_attributes][:address_attributes][:zip_code]
								}
							)
						end
            policy_user = @application.policy_users.create!(policy_user_params)
            policy_user.user.invite! if index == 0
          end
				end

        return error_status.include?(true) ? false : true
      end
      
      def create_rental_guarantee
        
        @application = PolicyApplication.new(create_rental_guarantee_params)
        
        if @application.agency.nil?
          @application.agency = Agency.where(master_agency: true).take 
        end

				@application.billing_strategy = BillingStrategy.where(agency: @application.agency, 
				                                                      policy_type: @application.policy_type).take
		    
		    if @application.save
  		    if create_policy_users()
    		    if @application.update(status: 'in_progress')
              # Commercial Application Saved
              
      		    @application.primary_user().invite!
      		    render "v2/public/policy_applications/show"
      		    							
      		  else
              render json: @application.errors.to_json,
                     status: 422					
  					end
  		    end		  		  
  		  else         
          # Rental Guarantee Application Save Error
          render json: @application.errors.to_json,
                 status: 422
        end     	  
	    end
      
      def create_commercial
        
        @application = PolicyApplication.new(create_commercial_params) 
        @application.agency = Agency.where(master_agency: true).take 

				@application.billing_strategy = BillingStrategy.where(agency: @application.agency, 
				                                                      policy_type: @application.policy_type,
				                                                      title: 'Annually').take
		    
		    if @application.save
		    
  		    if create_policy_users()
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
  	  						id: @application.id,
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
    									 status: 422							
    					end
  					else
              render json: @application.errors.to_json,
                     status: 422					
  					end
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
  	      if create_policy_users()
    	      if @application.update status: "complete"
  
            	# if application.status updated to complete
            	@application.qbe_estimate()
            	@quote = @application.policy_quotes.last
    					if @application.status != "quote_failed" || @application.status != "quoted"
    						# if application quote success or failure
    						@application.qbe_quote(@quote.id) 
    						@application.reload()
    						@quote.reload()
    						
    						if @quote.status == "quoted"	
    							
    							@application.primary_user().set_stripe_id()
    						  
    							render json: { 
  	  							id: @application.id,
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
  	      end
  	    else
          render json: @application.errors.to_json,
                 status: 422   
  	    end
      end      
      
      def update
        case params[:policy_application][:policy_type_id]
        when 1
          update_residential()
        when 5
        	update_rental_guarantee()
        else
          render json: { 
                   title: "Policy or Guarantee Type Not Recognized", 
                   message: "Only Residential Policies and Rental Guaranatees are available for update from this screen" 
                 }, status: 422
        end
      end
            
      def update_residential
	      @policy_application = PolicyApplication.find(params[:id])
	      
        if @policy_application.policy_type.title == "Residential"

					@policy_application.policy_rates.destroy_all
          
          if @policy_application.update(update_residential_params) && 
             @policy_application.update(status: "complete")
             
          	@policy_application.qbe_estimate()
          	@quote = @policy_application.policy_quotes.last
  					if @policy_application.status != "quote_failed" || @policy_application.status != "quoted"
  						# if application quote success or failure
  						@policy_application.qbe_quote(@quote.id) 
  						@policy_application.reload()
  						@quote.reload()
  						
  						if @quote.status == "quoted"	
  						  
  							render json: { 
	  							id: @policy_application.id,
  								quote: { 
  									id: @quote.id, 
  									status: @quote.status, 
  									premium: @quote.policy_premium 
  								},
  								invoices: @quote.invoices.order('due_date ASC'),
  								user: { 
  									id: @policy_application.primary_user().id,
  									stripe_id: @policy_application.primary_user().stripe_id
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
	          render json: @policy_application.errors.to_json,
	                 status: 422	
          end    
          
        else
        
        end
      end
      
      def update_rental_guarantee
	      @policy_application = PolicyApplication.find(params[:id])
	      
        if @policy_application.policy_type.title == "Rent Guarantee"
          
          if @policy_application.update(update_rental_guarantee_params) && 
             @policy_application.update(status: "complete") 
             
            quote_attempt = @policy_application.pensio_quote()
            
  					if quote_attempt[:success] == true
  						
  						@policy_application.primary_user().set_stripe_id()
  						
  						@quote = @policy_application.policy_quotes.last
  						invoice_errors = @quote.generate_invoices_for_term()
  						@premium = @quote.policy_premium
  						
  						response = { 
	  						id: @policy_application.id,
  							quote: { 
  								id: @quote.id,
  								status: @quote.status,
  								premium: @premium
  							},
                invoice_errors: invoice_errors,
  							invoices: @quote.invoices,
  							user: { 
  								id: @policy_application.primary_user().id,
  								stripe_id: @policy_application.primary_user().stripe_id
  							}
  						}
  							  
  						render json: response.to_json, status: 200
  																
  					else
  						render json: { error: "Quote Failed", message: quote_attempt[:message] },
  									 status: 422							
  					end             
                      	
          else
	          render json: @policy_application.errors.to_json,
	                 status: 422	
          end 
	      end
	    end
            
      private
	      
	      def view_path
	        super + '/policy_applications'
	      end
	        
	      def set_policy_application
		      puts "SET POLICY APPLICATION RUNNING ID: #{ params[:id] }"
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
	      
	      def create_rental_guarantee_params
  	      params.require(:policy_application)
  	            .permit(:effective_date, :expiration_date, :fields, :auto_pay, 
		      							:auto_renew, :billing_strategy_id, :account_id, :policy_type_id, 
		      							:carrier_id, :agency_id, fields: {})  
  	    end
  	    
  	    def create_policy_users_params
    	    params.require(:policy_application)
    	          .permit(policy_users_attributes: [
			      							:primary, :spouse, user_attributes: [
				      							:email, profile_attributes: [
					      							:first_name, :last_name, :job_title, 
					      							:contact_phone, :birth_date, :gender,
					      							:salutation
				      							], address_attributes: [
                              :city, :country, :county, :id, :latitude, :longitude,
                              :plus_four, :state, :street_name, :street_number,
                              :street_two, :timezone, :zip_code
				      							]
			      							]
			      					  ])  
    	  end
	      
	      def update_residential_params
  	      params.require(:policy_application)
  	            .permit(policy_rates_attributes: [:insurable_rate_id],
  	                   policy_insurables_attributes: [:insurable_id])  
  	    end
	      
	      def update_rental_guarantee_params
  	      params.require(:policy_application)
  	            .permit(:fields, fields: {})  
  	    end
	        
	      def valid_policy_types
	        return ["residential", "commercial", "rent-guarantee"]
	      end
        
    end
  end # module Public
end
