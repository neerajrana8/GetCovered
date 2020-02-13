##
# V2 User Payment Profiles Controller
# File: app/controllers/v2/user/payments_controller.rb

module V2
  module User
    class PaymentProfilesController < UserController
	    
	    def index
		    render json: current_user.payment_profiles.to_json,
		    			 status: :ok
		  end
		  
		  def create
				if current_user.attach_payment_source(create_params[:source])
					render json: current_user.payment_profiles.order("created_at").last.to_json,
								 status: :ok
				else
					render json: { error: "Failure", message: "Unable to attach payment source to user" }.to_json,
								 status: 422
				end
			end
			
			def update
				@profile = current_user.payment_profiles.find(params[:id])
					
				if @profile.update(update_params)
					render json: @profile.to_json,
								 status: :ok
				else
					render json: @profile.errors.to_json,
								 status: 422
				end	
			end
			
			private
			
				def create_params
					params.require(:payment_profile).permit(:source)
				end
				
				def update_params
					params.require(:payment_profile).permit(:active, :default_profile)
				end
	    
	  end
	end
end
