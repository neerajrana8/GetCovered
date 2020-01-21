# Get Covered Insurable Seed Setup File
# file: db/seeds/insurable.rb

require './db/seeds/functions'
require 'faker'

@addresses = [
	{
    street_number: "710",
    street_name: "S Main St",
    city: "Las Vegas",
    county: "CLARK",
    state: "NV",
    zip_code: "89101",
    plus_four: "6409",
    primary: true
  }# ,
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
]

@business_types = ['AssociationLaborUnionReligiousOrganization', 'CommonOwnership', 
									 'Corporation', 'ExecutororTrustee', 'PublicProperty', 'SoleProprietor', 
									 'JointEmployers', 'JointVenture', 'LimitedLiabilityPartnership', 
									 'LimitedPartnership', 'LLC', 'MultipleStatus', 'Partnership', 
									 'Trust','Other']
@expense_limits = [300000, 500000, 1000000, 2000000]

@addresses.each do |address|
	
	fake_user = {
		first_name: Faker::Name.first_name,
		last_name: Faker::Name.last_name,
		job_title: Faker::Job.title,
		birth_date: SeedFunctions.time_rand(Time.local(1955, 1, 1), Time.local(1991, 1, 1))
	}
	
	if address[:state] == "TX" || address[:state] == "FL"
		class_code = CarrierClassCode.where(state_code: address[:state], appetite: true)
																 .order("RANDOM()")
																 .take
	else
		class_code = CarrierClassCode.where
		                             .not(state_code: ["FL", "TX"])
																 .where(appetite: true)
																 .order("RANDOM()")
																 .take
	end
	
	fake_user_email = "#{fake_user[:first_name]}#{fake_user[:last_name]}@gmail.com".downcase
	
  @company = "#{ Faker::Company.name } #{ rand(0..1000) }"
	
	policy_start_date = Time.now + rand(1..30).days
	expense_limit = @expense_limits[rand(0..3)]
	start_date = (Time.now + rand(1..14).days)
  end_date = start_date + 1.years
  agency = Agency.find(1)
  carrier = Carrier.find(3)
  policy_type = PolicyType.find(4)

  @application = PolicyApplication.new(
		effective_date: start_date,
		expiration_date: end_date,
		status: "complete",
    policy_type: policy_type, 
    carrier: carrier,
    billing_strategy: BillingStrategy.where(agency: agency, carrier: carrier, policy_type: policy_type).take,
    agency: agency,
    policy_users_attributes: [
      { 
        primary: true,
        user_attributes: {
          email: fake_user_email, password: 'TestingPassword1234', 
	        password_confirmation: 'TestingPassword1234', 
	        profile_attributes: fake_user          
        }
      }
    ]
  )
  
  @application.build_from_carrier_policy_type()
  
  @application.fields = {
    "premise": [
      {
        "owned": [true, false][rand(0..1)],
        "address":  address,
        "sqr_footage": rand(800..2000).round(-2)
      }
    ],
    "business": {
      "phone": Faker::PhoneNumber.cell_phone,
      "website": "https://www.#{ @company.downcase.strip.tr(' ', '-').gsub(/[^\w-]/, '') }.com",
      "sub_class": class_code.sub_category,
      "class_code": class_code.class_code,
      "major_class": class_code.major_category,
      "annual_sales":  rand(100000..3000000).round(-3),
      "contact_name": "#{ fake_user[:first_name] } #{ fake_user[:last_name] }",
      "business_name": @company,
      "business_type": @business_types[rand(0..14)],
      "contact_email": fake_user_email,
      "contact_phone": Faker::PhoneNumber.cell_phone,
      "contact_title": fake_user[:job_title],
      "business_started": SeedFunctions.time_rand(Time.local(1975, 1, 1)),
      "number_of_insured": 1,
      "full_time_employees": rand(3..5),
      "part_time_employees": rand(0..1),
      "business_description": Faker::Company.catch_phrase
    },
    "policy_limits":  {
      "liability": expense_limit,
      "building_limit": rand(25000..1000000).round(-3),
      "aggregate_limit": expense_limit * 2,
      "business_personal_property": rand(25000..500000).round(-3)
    }
  }
  
  if @application.save!
 		pp @application.crum_quote()
	else
	  puts @application.valid?
	  
	  @application.policy_users.each do |pu|
  	  puts pu.valid?
  	  pp pu.errors
  	  puts pu.user.valid?
  	  pp pu.user.errors
  	  puts pu.user.profile.valid?
  	  pp pu.user.profile.errors
    end
    
	  pp @application.errors
	end
end