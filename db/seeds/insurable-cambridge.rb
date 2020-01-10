# Get Covered Insurable Seed Setup File
# file: db/seeds/insurable-cambridge.rb

require './db/seeds/functions'
require 'socket'

InsurableType.create(title: "Residential Building", 
                     category: "property", 
                     enabled: true) unless InsurableType.exists?(title: "Residential Building")

@occupant_shield = Account.new(title: "Occupant Shielf", enabled: true, whitelabel: true, 
															 tos_accepted: true, tos_accepted_at: Time.current, 
															 tos_acceptance_ip: Socket.ip_address_list.select{ |intf| intf.ipv4_loopback? }, 
															 verified: true, stripe_id: nil, agency: Agency.where(title: "Cambridge GC").take,
														   addresses_attributes: [
													  		{
													  			street_number: "100",
													  			street_name: "Pearl Street",
													  			street_two: "14th Floor",
													  			city: "Hartford",
													  			state: "CT",
													  			county: "HARTFORD COUNTY",
													  			zip_code: "06103",
													  			primary: true
													  		}																	   
														   ])

if @occupant_shield.save
	SeedFunctions.adduser(Staff, { 
		email: "mel@getcoveredllc.com", 
		password: 'TestingPassword1234', 
		password_confirmation: 'TestingPassword1234', 
		role: 'staff', 
		enabled: true, 
		organizable: @occupant_shield, 
  	profile_attributes: { 
	  	first_name: 'Melissa', 
	  	last_name: 'Christman', 
	  	job_title: 'Operations Manager', 
	  	birth_date: '04-01-1989'.to_date 
	  }	
	})	
else
	pp @occupant_shield.errors
end
    																 
@cambridge_community = Insurable.new(title: "Residences at Executive Park",
                                     insurable_type: InsurableType.find(1), 
																		 enabled: true, category: 'property',
																		 account: @occupant_shield,
																		 addresses_attributes: [
																		   {
																		 	   street_number: "1",
																		 	   street_name: "Vanderbilt Dr.",
																		 	   city: "Merrimack",
																		 	   state: "NH",
																		 	   zip_code: "03054"
																		   }
																		 ])

if @cambridge_community.save
	
	@cambridge_community.create_carrier_profile(1)
	
	@profile = @cambridge_community.carrier_profile(1)
	@profile.traits["protection_device_cd"] = "S"
	@profile.traits["construction_type"] = "R"
	@profile.traits["construction_year"] = 2019
	@profile.traits["professionally_managed"] = true
	@profile.traits["professionally_managed_year"] = 2019
	@profile.save
	
	Assignment.create!(staff: @occupant_shield.owner, assignable: @cambridge_community)

	@cambridge_community.get_qbe_zip_code()
	@cambridge_community.get_qbe_property_info()
	
  @five_vanderbilt = Insurable.new(title: "Five Vanderbilt", insurable_type: InsurableType.find(7), 
  																 enabled: true, category: 'property', insurable: @cambridge_community,
  																 account: @occupant_shield, addresses_attributes: [
																     {
																 	     street_number: "5",
																 	     street_name: "Vanderbilt Dr.",
																 	     city: "Merrimack",
																 	     state: "NH",
																 	     zip_code: "03054"
																     }
																   ])
	if @five_vanderbilt.save
		# 5 Vanderbilt Dr.
		[101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 201, 
		 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 301, 302, 
		 303, 304, 305, 306, 307, 308, 309, 310, 311, 401, 402, 403, 
		 404, 405, 406, 407, 408, 409, 410, 411].each do |unit|
			 
			@unit = @five_vanderbilt.insurables.new(title: "#{ unit } at #{ @five_vanderbilt.title }", insurable_type: InsurableType.find(4),
																					    enabled: true, category: 'property', account: @occupant_shield)
			
			if @unit.save
			  @unit.create_carrier_profile(1)
			else
			  puts "\nUnit Save Error\n\n"
			  pp @unit.errors.to_json
			end	
				  	 
	  end			
	else
		pp @five_vanderbilt.errors
	end	
	
  @three_vanderbilt = Insurable.new(title: "Three Vanderbilt", insurable_type: InsurableType.find(7), 
  																 enabled: true, category: 'property', insurable: @cambridge_community,
  																 account: @occupant_shield, addresses_attributes: [
																     {
																 	     street_number: "3",
																 	     street_name: "Vanderbilt Dr.",
																 	     city: "Merrimack",
																 	     state: "NH",
																 	     zip_code: "03054"
																     }
																   ])
  
  if @three_vanderbilt.save
		# 3 Vanderbilt Drive
		[101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 
		 113, 114, 115, 116, 201, 202, 203, 204, 205, 206, 207, 208, 
		 209, 210, 211, 212, 213, 214, 215, 216, 301, 302, 303, 304, 
		 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 316, 
		 401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 
		 413, 414, 415, 416].each do |unit|
			 
			@unit = @three_vanderbilt.insurables.new(title: "#{ unit } at #{ @three_vanderbilt.title }", insurable_type: InsurableType.find(4),
																					    enabled: true, category: 'property', account: @occupant_shield)
			
			if @unit.save
			  @unit.create_carrier_profile(1)
			else
			  puts "\nUnit Save Error\n\n"
			  pp @unit.errors.to_json
			end	
			 
		end
	else
		pp @three_vanderbilt.errors
	end
	
  @four_executive = Insurable.new(title: "Four Executive", insurable_type: InsurableType.find(7), 
  																 enabled: true, category: 'property', insurable: @cambridge_community,
  																 account: @occupant_shield, addresses_attributes: [
																     {
																 	     street_number: "4",
																 	     street_name: "Executive Park Dr.",
																 	     city: "Merrimack",
																 	     state: "NH",
																 	     zip_code: "03054"
																     }
																   ])
  
  if @four_executive.save
		# 4 Executive Park Drive
		[101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 
		 113, 114, 115, 116, 201, 202, 203, 204, 205, 206, 207, 208, 
		 209, 210, 211, 212, 213, 214, 215, 216, 301, 302, 303, 304, 
		 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 316, 
		 401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 
		 413, 414, 415, 416].each do |unit|
			 
			@unit = @four_executive.insurables.new(title: "#{ unit } at #{ @four_executive.title }", insurable_type: InsurableType.find(4),
																					    enabled: true, category: 'property', account: @occupant_shield)
			
			if @unit.save
			  @unit.create_carrier_profile(1)
			else
			  puts "\nUnit Save Error\n\n"
			  pp @unit.errors.to_json
			end	
			 
		end
	else
		pp @four_executive.errors
	end
	
  @two_pan_american = Insurable.new(title: "Two Pan American", insurable_type: InsurableType.find(7), 
  																 enabled: true, category: 'property', insurable: @cambridge_community,
  																 account: @occupant_shield, addresses_attributes: [
																     {
																 	     street_number: "2",
																 	     street_name: "Pan American Dr.",
																 	     city: "Merrimack",
																 	     state: "NH",
																 	     zip_code: "03054"
																     }
																   ])
  
  if @two_pan_american.save
		# 2 Pan American Drive
		[101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 201, 
		 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 301, 302, 
		 303, 304, 305, 306, 307, 308, 309, 310, 311, 401, 402, 403, 
		 404, 405, 406, 407, 408, 409, 410, 411].each do |unit|
			 
			@unit = @two_pan_american.insurables.new(title: "#{ unit } at #{ @two_pan_american.title }", insurable_type: InsurableType.find(4),
																					    enabled: true, category: 'property', account: @occupant_shield)
			
			if @unit.save
			  @unit.create_carrier_profile(1)
			else
			  puts "\nUnit Save Error\n\n"
			  pp @unit.errors.to_json
			end	
			 
		end
	else
		pp @two_pan_american.errors
	end
	
  @one_pan_american = Insurable.new(title: "One Pan American", insurable_type: InsurableType.find(7), 
  																 enabled: true, category: 'property', insurable: @cambridge_community,
  																 account: @occupant_shield, addresses_attributes: [
																     {
																 	     street_number: "1",
																 	     street_name: "Pan American Dr.",
																 	     city: "Merrimack",
																 	     state: "NH",
																 	     zip_code: "03054"
																     }
																   ])
  
  if @one_pan_american.save
		# 1 Pan American Drive
		[101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 
		 113, 114, 115, 116, 201, 202, 203, 204, 205, 206, 207, 208, 
		 209, 210, 211, 212, 213, 214, 215, 216, 301, 302, 303, 304, 
		 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 316, 
		 401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 
		 413, 414, 415, 416].each do |unit|
			 
			@unit = @one_pan_american.insurables.new(title: "#{ unit } at #{ @one_pan_american.title }", insurable_type: InsurableType.find(4),
																					    enabled: true, category: 'property', account: @occupant_shield)
			
			if @unit.save
			  @unit.create_carrier_profile(1)
			else
			  puts "\nUnit Save Error\n\n"
			  pp @unit.errors.to_json
			end	
			 
		end
	else
		pp @one_pan_american.errors
	end
 
	@cambridge_community.reset_qbe_rates(true, true)
  @cambridge_community.insurable_rates.optional.update_all mandatory: true
  
  enabled_cov_c_rates_ids = []
  enabled_cov_c_rates_ids.concat @cambridge_community.insurable_rates.coverage_c.where("(coverage_limits ->> 'coverage_c')::integer = ?", 1000000).map(&:id)
  enabled_cov_c_rates_ids.concat @cambridge_community.insurable_rates.coverage_c.where("(coverage_limits ->> 'coverage_c')::integer = ?", 1500000).map(&:id)
  enabled_cov_c_rates_ids.concat @cambridge_community.insurable_rates.coverage_c.where("(coverage_limits ->> 'coverage_c')::integer = ?", 2000000).map(&:id)
  
  enabled_liability_rates_ids = @cambridge_community.insurable_rates.liability.where("(coverage_limits ->> 'liability')::integer = ?", 10000000).map(&:id)
  
  @cambridge_community.insurable_rates.coverage_c.where.not(id: enabled_cov_c_rates_ids).update_all enabled: false
  @cambridge_community.insurable_rates.liability.where.not(id: enabled_liability_rates_ids).update_all enabled: false
  
else
	pp @cambridge_community.errors
end