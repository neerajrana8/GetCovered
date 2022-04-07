##
# V2 QBE Controller
# File: app/controllers/v2/staff_account_controller.rb

module V2
  class QbeController < V2Controller
	  before_action :check_api_access    
		
		def list
			
			unless params["sourceInfo"].blank? || 
					 	 params["sourceInfo"]["zipCodeRequest"].blank? ||
					 	 params["sourceInfo"]["zipCodeRequest"]["zipCode"].blank? ||
					 	 params["sourceInfo"]["zipCodeRequest"]["Agent_Number"].blank?
				
				carrier_agency = CarrierAgency.find_by_external_carrier_id(params["sourceInfo"]["zipCodeRequest"]["Agent_Number"])
				
				unless carrier_agency.nil?
  				@agency = carrier_agency.agency
					@community_ids = @agency.insurables.communities.pluck(:id)
					@addresses = Address.includes(:addressable)
															.where(zip_code: params["sourceInfo"]["zipCodeRequest"]["zipCode"].to_s,
																		 addressable_id: @community_ids,
																		 addressable_type: "Insurable")
          @communities = []
					@addresses.each do |address|
						community = address.addressable
						profile = community.carrier_profile(1)
						@communities << community unless profile.nil? || profile.traits["pref_facility"] != "MDU"
					end

        else
  				render json: { statusCd: "Error", statusMessage: "Missing or improperly formatted Agent Number" }.to_json,
  						 status: :unprocessable_entity
        end
			else
				render json: { statusCd: "Error", statusMessage: "Missing or improperly formatted Zip Code or Agent Number" }.to_json,
						 status: :unprocessable_entity
			end
		end
		
		def show
			
			return_unprocessable = true
			
			agency_qbe_id = params["SourceInfo"].blank? ? nil : params["SourceInfo"]["agent_number"]
			community_qbe_id = params["ZipCodeRQ"]["Community_ID"]
			
			unless community_qbe_id.nil? || agency_qbe_id.nil?
  			carrier_agency = CarrierAgency.where(external_carrier_id: agency_qbe_id).take
				unless carrier_agency.nil?
  				@agency = carrier_agency.agency
  				
  				carrier_insurable_profile = CarrierInsurableProfile.where(external_carrier_id: params["ZipCodeRQ"]["Community_ID"]).take
				  @community = @agency.insurables.find(carrier_insurable_profile.insurable_id)
          
				  return_unprocessable = false unless @community.nil?
				else
    			render json: { statusCd: "Error", statusMessage: "Community not available, Zip Code improperly formated or invalid / missing Agent Number" }.to_json,
    					 status: :unprocessable_entity if	return_unprocessable					
        end
			end

			render json: { statusCd: "Error", statusMessage: "Community not available, Zip Code improperly formated or invalid / missing Agent Number" }.to_json,
					 status: :unprocessable_entity if	return_unprocessable			
		end
			
		private
			def check_api_access
				key = request.headers["security-key"]
				secret = request.headers["security-secret"]
				pass = false
				
				unless key.nil? || 
							 secret.nil?
				 
					access_token = AccessToken.find_by_key(key)
				  
					if !access_token.nil? && 
						 access_token.check_secret(secret)
						pass = true
					end
				end
				
				render json: { statusCd: "Error", statusMessage: "Authenticaion Headers Not Accepted" }.to_json,
						 status: 401 unless pass
			end
      
  end
end
