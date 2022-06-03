json.communityId do
	json.location do
  	if @community.community_with_buildings
      json.array!(@community.insurables) do |i|
        
        json.address do
  				json.addressId i.primary_address().id
  				json.addressLine1 i.primary_address().combined_street_address
  				json.addressLine2 i.primary_address().street_two	        
  		  end
  		
  			json.apartmentList do
  				json.apartments do
  					json.array!(i.insurables.order(:title)) do |unit|
  						json.apartmentId unit.carrier_profile(1).external_carrier_id
  						json.unitNumber unit.title.nil? ? nil : unit.title.gsub(/[^0-9,.]/, "")
  					end
  				end
  			end
          
      end    	
    else
  		json.array!([1]) do |i|
  			
  			json.address do
  				json.addressId @address.id
  				json.addressLine1 @address.combined_street_address
  				json.addressLine2 @address.street_two
  			end
  		
  			json.apartmentList do
  				json.apartments do
  					json.array!(@community.insurables.order(:title)) do |unit|
  						json.apartmentId unit.carrier_profile(1).nil? ? nil : unit.carrier_profile(1).external_carrier_id
  						json.unitNumber unit.title.nil? ? nil : unit.title.gsub(/[^0-9,.]/, "")
  					end
  				end
  			end
  			
  		end
  	end	
	end
	json.status do
		json.statusCd "Success"
		json.statusMessage nil
	end	
end