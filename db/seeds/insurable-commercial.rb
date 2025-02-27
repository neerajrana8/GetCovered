# Get Covered Insurable Seed Setup File
# file: db/seeds/insurable-commercial.rb

# require './db/seeds/functions'
# require 'faker'
# 
# @addresses = [
# 	{
#     street_number: "710",
#     street_name: "S Main St",
#     city: "Las Vegas",
#     county: "CLARK",
#     state: "NV",
#     zip_code: "89101",
#     plus_four: "6409",
#     primary: true
#   },
#   {
#     street_number: "2506",
#     street_name: "E 7th St",
#     city: "Austin",
#     county: "TRAVIS",
#     state: "TX",
#     zip_code: "78702",
#     plus_four: "3249",
#     primary: true
#   },
#   {
#     street_number: "1127",
#     street_name: "Kansas Ave",
#     city: "Kansas City",
#     county: "WYANDOTTE",
#     state: "KS",
#     zip_code: "66105",
#     plus_four: "1101",
#     primary: true
#   },
#   {
#     street_number: "1711",
#     street_name: "Snelling Ave N",
#     city: "St Paul",
#     county: "RAMSEY",
#     state: "MN",
#     zip_code: "55113",
#     plus_four: "1003",
#     primary: true
#   },
#   {
#     street_number: "1102",
#     street_name: "Autumn Creek Way",
#     city: "Manchester",
#     county: "SAINT LOUIS",
#     state: "MO",
#     zip_code: "63088",
#     plus_four: "1289",
#     primary: true
#   },
#   {
#     street_number: "240",
#     street_name: "Hickory Hedge Drive",
#     city: "Manchester",
#     county: "SAINT LOUIS",
#     state: "MO",
#     zip_code: "63021",
#     plus_four: "5707",
#     primary: true
#   },
#   {
#     street_number: "7111",
#     street_name: "Jefferson Run Dr",
#     city: "Louisville",
#     county: "JEFFERSON",
#     state: "KY",
#     zip_code: "40219",
#     plus_four: "3078",
#     primary: true
#   },
#   {
#     street_number: "13900",
#     street_name: "Steelecroft Farm Lane",
#     city: "Charlotte",
#     county: "MECKLENBURG",
#     state: "NC",
#     zip_code: "28278",
#     plus_four: "7493",
#     primary: true
#   },
#   {
#     street_number: "1340",
#     street_name: "Washington Blvd",
#     city: "Stamford",
#     county: "FAIRFIELD",
#     state: "CT",
#     zip_code: "06902",
#     plus_four: "2452",
#     primary: true
#   },
#   {
#     street_number: "70",
#     street_name: "Bonita Dr.",
#     city: "Depew",
#     county: "Erie",
#     state: "NY",
#     zip_code: "14043",
#     plus_four: "1508",
#     primary: true
#   },
#   {
#     street_number: "105",
#     street_name: "N Elm St",
#     city: "Mahomet",
#     county: "Champaign",
#     state: "IL",
#     zip_code: "61853",
#     plus_four: "9364",
#     primary: true
#   }  
# ]
# 
# @used_company_names = Array.new
# @used_company_file = "#{ Rails.root }/db/seeds/_used_name_list.txt"
# File.open(@used_company_file).each { |line| @used_company_names << line }
# 
# @business_types = ['AssociationLaborUnionReligiousOrganization', 'CommonOwnership', 
# 									 'Corporation', 'ExecutororTrustee', 'PublicProperty', 'SoleProprietor', 
# 									 'JointEmployers', 'JointVenture', 'LimitedLiabilityPartnership', 
# 									 'LimitedPartnership', 'LLC', 'MultipleStatus', 'Partnership', 
# 									 'Trust','Other']
# @expense_limits = [300000, 500000, 1000000, 2000000]
# 
# 90.times do |iteration|
# 	puts "Round: #{ iteration }"
# 	@addresses.each do |address|
# 		puts "State #{ address[:state] }"
# 		
# 		fake_user = {
# 			first_name: Faker::Name.first_name,
# 			last_name: Faker::Name.last_name,
# 			title: Faker::Job.title
# 		}
# 		
# 		if address[:state] == "TX" || address[:state] == "FL"
# 			class_code = CarrierClassCode.where(state_code: address[:state], appetite: true)
# 																	 .order("RANDOM()")
# 																	 .take
# 		else
# 			class_code = CarrierClassCode.where
# 			                             .not(state_code: ["FL", "TX"])
# 																	 .where(appetite: true)
# 																	 .order("RANDOM()")
# 																	 .take
# 		end
# 		
# 		fake_user[:email] = "#{fake_user[:first_name]}#{fake_user[:last_name]}@gmail.com".downcase
# 	
# 	  loop do
# 	    @company = "#{ Faker::Company.name } #{ rand(0..1000) }"
# 	    break unless @used_company_names.include?(@company)
# 	  end
# 	
# 		open(@used_company_file, 'a') do |f|
# 		  f.puts "#{ @company }\n"
# 		end
# 		
# 		policy_start_date = Time.now + rand(1..30).days
# 		expense_limit = @expense_limits[rand(0..3)]
# 		
# 		request = {
# 			user_email: fake_user[:email],
# 			policy_start_date: policy_start_date,
# 			policy_end_date: policy_start_date + 1.years,
# 			business: {
# 				number_of_insured: 1,
# 				business_name: @company,
# 				business_type: @business_types[rand(0..14)],
# 				phone: Faker::PhoneNumber.cell_phone,
# 				website: "https://www.#{ @company.downcase.strip.tr(' ', '-').gsub(/[^\w-]/, '') }.com",
# 				contact_name: "#{ fake_user[:first_name] } #{ fake_user[:last_name] }",
# 				contact_title: fake_user[:title],
# 				contact_phone: Faker::PhoneNumber.cell_phone,
# 				contact_email: fake_user[:email],
# 				business_started: SeedFunctions.time_rand(Time.local(1975, 1, 1)),
# 				business_description: Faker::Company.catch_phrase,
# 				full_time_employees: rand(3..5),
# 				part_time_employees: rand(0..1),
# 				major_class: class_code.major_category,
# 				sub_class: class_code.sub_category,
# 				class_code: class_code.class_code,	
# 				annual_sales: rand(100000..3000000).round(-3)	
# 			},
# 			premise: {
# 				address: address,
# 				owned: ["yes", "no"][rand(0..1)],	
# 				sqr_footage: rand(800..2000).round(-2),
# 			},
# 			policy_limits: {
# 				liability: expense_limit,
# 				aggregate_limit: expense_limit * 2,
# 				building_limit: rand(25000..1000000).round(-3),
# 				business_personal_property: rand(25000..500000).round(-3)			
# 			}
# 		}
# 	
# 		crum_service = CrumService.new()
# 		crum_service.add_new_quote(request)
# 		
# 	end
# end