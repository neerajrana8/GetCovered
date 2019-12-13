##
# V2 QBE Controller
# File: app/controllers/v2/staff_account_controller.rb

module V2
  class QbeController < V2Controller
    
		def list
			
			unless params["sourceInfo"].blank? || 
					 	 params["sourceInfo"]["zipCodeRequest"].blank? ||
					 	 params["sourceInfo"]["zipCodeRequest"]["zipCode"].blank? ||
					 	 params["sourceInfo"]["zipCodeRequest"]["Agent_Number"].blank?
				
				carrier_agency = CarrierAgency.where(external_carrier_id: params["sourceInfo"]["zipCodeRequest"]["Agent_Number"]).take
				
				unless carrier_agency.nil?
  				@agency = carrier_agency.agency

          @communities = []
          @prelim_communities = @agency.insurables.where(insurable_type_id: 1).each do |i|
            profile = i.carrier_profile(1)
            @communities << i if profile.traits["pref_facility"] == "MDU"  
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
			
			agency_qbe_id = params["agent_number"]
			community_qbe_id = params["ZipCodeRQ"]["Community_ID"].to_i
			
			unless community_qbe_id.nil? || agency_qbe_id.nil?
  			carrier_agency = CarrierAgency.where(external_carrier_id: params["agent_number"]).take
				unless carrier_agency.nil?
  				@agency = carrier_agency.agency
  				
  				carrier_insurable_profile = CarrierInsurableProfile.where(external_carrier_id: params["ZipCodeRQ"]["Community_ID"]).take
				  @community = @agency.insurables.find(carrier_insurable_profile.insurable_id)
        
				  return_unprocessable = false unless @community.nil?
        end
			end

			render json: { statusCd: "Error", statusMessage: "Community not available, Zip Code improperly formated or invalid / missing Agent Number" }.to_json,
					 status: :unprocessable_entity if	return_unprocessable			
		end
		
		def details
			
			return_unprocessable = true
			
			unless params["ZipCodeRQ"].blank? || 
						 params["ZipCodeRQ"]["Community_ID"].blank?
				@community = Community.includes(:address, buildings: [:units])
															.find_by_qbe_id(Integer(params["ZipCodeRQ"]["Community_ID"]))
				return_unprocessable = true unless @community.nil?
			end

			render json: { statusCd: "Error", statusMessage: "Community not available or Zip Code improperly formated" }.to_json,
					 status: :unprocessable_entity if	return_unprocessable	
		end
			
    private
      
  end
end
