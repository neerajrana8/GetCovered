json.communityId do
	json.location do
		json.array!([1]) do |i|
			
			json.address do
				json.addressId @community.primary_address().id
				json.addressLine1 @community.primary_address().combined_street_address
				json.addressLine2 @community.primary_address().street_two	
			end
		
			json.apartmentList do
				json.apartments do
					json.array!(@community.insurables.order(:title)) do |unit|
						json.apartmentId unit.carrier_profile(1).external_carrier_id
						json.unitNumber unit.title
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