##
# V2 StaffAccount Payment Profiles Controller
# File: app/controllers/v2/staff_account/payments_controller.rb

module V2
	module StaffAccount
		class PaymentProfilesController < StaffAccountController
			
			def index
				render json: current_staff.organizable.payment_profiles.to_json, status: :ok
			end
			
			def create
				result = current_staff.organizable.attach_payment_source(create_params[:source])
				if result.valid?
					render json: current_staff.organizable.payment_profiles.order("created_at").last.to_json, status: :created
				else
					render json: { error: "Failure", message: result.errors.full_messages.join(' and ') }.to_json, status: 422
				end
			end
			
			def update
				@profile = current_staff.organizable.payment_profiles.find(params[:id])
				
				if @profile.update(update_params)
					render json: @profile.to_json, status: :ok
				else
					render json: @profile.errors.to_json, status: 422
				end	
			end

			def set_default
				@profile = current_staff.organizable.payment_profiles.find(params[:id])
				if @profile.set_default
					render json: @profile.to_json, status: :ok
				else
					render json: @profile.errors.to_json, status: 422
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
