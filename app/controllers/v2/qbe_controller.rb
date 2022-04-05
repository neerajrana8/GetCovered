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
				
				carrier_agency = CarrierAgency.where(external_carrier_id: params["sourceInfo"]["zipCodeRequest"]["Agent_Number"]).take
				
				unless carrier_agency.nil?
  				@agency = carrier_agency.agency

          @communities = []
          @agency.insurables.where(insurable_type_id: 1).each do |i|
            profile = i.carrier_profile(1)
						address = i.primary_address()
						unless profile.nil?
							if profile.traits["pref_facility"] == "MDU"
								unless address.nil?
									@communities << i if address.zip_code == params["sourceInfo"]["zipCodeRequest"]["zipCode"].to_s
								end
							end
						end
          end
          						 	 
        else
  				render json: { statusCd: "Error", statusMessage: "Missing or improperly formated Agent Number" }.to_json,
  						 status: :unprocessable_entity
        end
			else
				render json: { statusCd: "Error", statusMessage: "Missing or improperly formated Zip Code or Agent Number" }.to_json,
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
