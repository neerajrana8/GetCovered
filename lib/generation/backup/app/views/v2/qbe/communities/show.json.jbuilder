json.communityId do
	json.location do
		json.array!(@community.buildings) do |building|
			
			json.address do
				json.addressId building.address.id
				json.addressLine1 building.address.combined_street_address
				json.addressLine2 building.address.street_two	
			end
		
			json.apartmentList do
				json.apartments do
					json.array!(building.units.order(:mailing_id)) do |unit|
						json.apartmentId unit.qbe_id
						json.unitNumber unit.mailing_id
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