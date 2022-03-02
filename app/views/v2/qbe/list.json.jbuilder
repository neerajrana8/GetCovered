json.status do
	json.statusCd "Success"
	json.statusMessage nil
end

json.communityList do
	json.communityCount @communities.count
	json.communities do
		json.array!(@communities) do |community|
			json.communityID community.carrier_profile(1).external_carrier_id
			json.communityName community.title
			json.unitNumber nil
			json.addressLine1 community.primary_address().combined_street_address
			json.addressLine2 community.primary_address().street_two
			json.city community.primary_address().city
			json.state community.primary_address().state
			json.county community.primary_address().county
			json.zipCode community.primary_address().zip_code
			json.cityLimit community.carrier_profile(1).traits['in_city_limits']
			json.propertyMgmtCompany community.account.title
			json.propertyManager nil
			json.units community.units.confirmed.count
			json.ageOfFacility community.carrier_profile(1).traits['construction_year']
			json.gatedCommunity community.carrier_profile(1).traits['gated']
			json.yearProfManaged community.carrier_profile(1).traits['professionally_managed_year']
			json.bCEGCode community.carrier_profile(1).traits['bceg']
			json.protClass nil
			json.constructionType community.carrier_profile(1).traits['construction_type']
			json.protectionDeviceCode community.carrier_profile(1).traits['protection_device_c']
		end
	end
end
