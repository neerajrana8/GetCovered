json.status do
	json.statusCd "Success"
	json.statusMessage nil
end

json.communityList do
	json.communityCount @communities.count
	json.communities do
		json.array!(@communities) do |community|
			json.communityID community.qbe_id
			json.communityName community.name
			json.unitNumber nil
			json.addressLine1 community.address.combined_street_address
			json.addressline2 community.address.street_two
			json.city community.address.locality
			json.status community.address.region
			json.county community.address.county
			json.cityLimit community.in_city_limits
			json.propertyMgmtCompany community.account.title
			json.propertyManager community.primary_staff.profile.full_name
			json.units community.units.count
			json.ageOfFacility community.construction_year
			json.gatedCommunity community.gated_access
			json.yearProfManaged community.professionally_managed_year
			json.bCEGCode community.bceg
			json.protClass nil
			json.constructionType community.construction_type
			json.protectionDeviceCode community.protection_device
		end
	end
end