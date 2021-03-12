# Get Covered Agency Seed Setup File
# file: db/seeds/agency.rb

require './db/seeds/functions'
require 'faker'
require 'socket'

##
# Setting up carriers as individual instance variables
#
@qbe = Carrier.find(1)           # Residential Carrier
@qbe_specialty = Carrier.find(2) # Also qbe, but has to be a seperate entity for reasons i dont understand
@crum = Carrier.find(3)          # Commercial Carrier
@pensio = Carrier.find(4)
@msi = Carrier.find(5) unless ENV['skip_msi']          # Residential Carrier


##
# Set Up Get Covered
#

@get_covered = Agency.new(
	title: "Get Covered", 
	enabled: true, 
	whitelabel: true, 
	tos_accepted: true, 
	tos_accepted_at: Time.current, 
	tos_acceptance_ip: nil, 
	verified: false, 
	stripe_id: nil, 
	master_agency: true,
	addresses_attributes: [
		{
			street_number: "265",
			street_name: "Canal St",
			street_two: "#205",
			city: "New York",
			state: "NY",
			county: "NEW YORK",
			zip_code: "10013",
			primary: true
		}
	]	  
)

if @get_covered.save
  site_staff = [
    { email: "dylan@getcoveredllc.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: @get_covered, 
      profile_attributes: { first_name: 'Dylan', last_name: 'Gaines', job_title: 'Chief Technical Officer', birth_date: '04-01-1989'.to_date }},
    { email: "brandon@getcoveredllc.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: @get_covered, 
      profile_attributes: { first_name: 'Brandon', last_name: 'Tobman', job_title: 'Chief Executive Officer', birth_date: '18-11-1983'.to_date }},
    { email: "baha@getcoveredllc.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: @get_covered, 
      profile_attributes: { first_name: 'Baha', last_name: 'Sagadiev'}},
    { email: 'super_admin@getcovered.com', password: 'Test1234', password_confirmation: 'Test1234', role: 'super_admin', enabled: true,
			profile_attributes: { first_name: 'Super', last_name: 'Admin', job_title: 'Super Admin', birth_date: '01-01-0001'.to_date }},
		{ email: 'agent@getcovered.com', password: 'Test1234', password_confirmation: 'Test1234', role: 'agent', enabled: true, organizable: @get_covered,
			profile_attributes: { first_name: 'Agent', last_name: 'Agent', job_title: 'Agent' }}
	]
  
  site_staff.each do |staff|
    SeedFunctions.adduser(Staff, staff)
  end

  @get_covered.carriers << @qbe 
  @get_covered.carriers << @qbe_specialty
  @get_covered.carriers << @crum  
  @get_covered.carriers << @pensio
  @get_covered.carriers << @msi unless ENV['skip_msi']
  
  CarrierAgency.where(agency_id: @get_covered.id, carrier_id: @qbe.id).take
               .update(external_carrier_id: "GETCVR")

  gc_commission_strategies = {
    @qbe => 30,
    @crum => 15,
    @msi => 30
  }.map do |carrier, percent|
    [
      carrier,
      ::CommissionStrategy.create!(
        title: "Get Covered / #{carrier.title} Commission",
        percentage: percent,
        recipient: @get_covered,
        commission_strategy: ::CommissionStrategy.where(recipient: carrier, commission_strategy_id: nil).take
      )
    ]
  end.to_h

  @get_covered.carriers.each do |carrier|
  
    commission_strategy = (gc_commission_strategies[carrier] ||= ::CommissionStrategy.create!(
      title: "Get Covered / #{carrier.title} Commission",
      percentage: 20, # use 20 as a default if there's no entry
      recipient: @get_covered,
      commission_strategy: ::CommissionStrategy.where(recipient: carrier, commission_strategy_id: nil).take
    ))
  
  	51.times do |state|
  		
  		@policy_type = nil
  		@fee_amount = nil
  		
  		if carrier.id == 1
  			@policy_type = PolicyType.find(1)
  			@fee_amount = 2500
  		elsif carrier.id == 2
  			@policy_type = PolicyType.find(2)
  		elsif carrier.id == 3
  			@policy_type = PolicyType.find(4)
  			@fee_amount = 2500
  		elsif carrier.id == 5 # MOOSE WARNING: testing fee
  			@policy_type = PolicyType.find(1)
  			@fee_amount = 2500
  		end
  		
  	  available = state == 0 || state == 11 ? false : true # we dont do business in Alaska (0) and Hawaii (11)
  	  authorization = CarrierAgencyAuthorization.create(state: state, 
  	  																									available: available, 
  	  																									carrier_agency: CarrierAgency.where(carrier: carrier, agency: @get_covered).take, 
  	  																									policy_type: @policy_type,
                                                        commission_strategy: commission_strategy)
  	  Fee.create(title: "Service Fee", 
  	  					 type: :MISC, 
  	  					 per_payment: false,
  	  					 amortize: false, 
  	  					 amount: @fee_amount, 
  	  					 amount_type: :FLAT, 
  	  					 enabled: true, 
  	  					 assignable: authorization, 
  	  					 ownerable: @get_covered) unless @fee_amount.nil?
  	end	
  end
  
  service_fee = { 
		title: "Service Fee", 
		type: :MISC,
		amount_type: "PERCENTAGE", 
		amortize: true,
		amount: 5, 
		enabled: true, 
		ownerable: @get_covered 
	}

  @get_covered.billing_strategies.create!(title: 'Annually', enabled: true, carrier: @qbe, 
                                    				policy_type: PolicyType.find(1), carrier_code: "FL",
                                            new_business: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 
                                                            payments_per_term: 1, remainder_added_to_deposit: true }, 
                                    				fees_attributes: [service_fee])
                                    
  @get_covered.billing_strategies.create!(title: 'Bi-Annually', enabled: true,  carrier_code: "SA",
  		                                      new_business: { payments: [50, 0, 0, 0, 0, 0, 50, 0, 0, 0, 0, 0], 
  		                                                      payments_per_term: 2, remainder_added_to_deposit: true },
  		                                      carrier: @qbe, policy_type: PolicyType.find(1), 
                                    				fees_attributes: [service_fee])
                                    
  @get_covered.billing_strategies.create!(title: 'Quarterly', enabled: true,  carrier_code: "QT",
  		                                      new_business: { payments: [25, 0, 0, 25, 0, 0, 25, 0, 0, 25, 0, 0], 
  		                                                      payments_per_term: 4, remainder_added_to_deposit: true },
  		                                      carrier: @qbe, policy_type: PolicyType.find(1), 
                                    				fees_attributes: [service_fee])
                                    
  @get_covered.billing_strategies.create!(title: 'Monthly', enabled: true, carrier_code: "QBE_MoRe",
  		                                      new_business: { payments: [22.01, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09], 
  		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
  		                                      renewal: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], 
  		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
  		                                      carrier: @qbe, policy_type: PolicyType.find(1), 
                                    				fees_attributes: [service_fee])

  ##
  # Crum / Get Covered Billing & Comission Strategies
                                    
  @get_covered.billing_strategies.create!(title: 'Monthly', enabled: true,  carrier_code: "M09",
		                                      new_business: { payments: [25.03, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 0, 0], 
		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
		                                      renewal: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], 
		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
		                                      carrier: @crum, policy_type: PolicyType.find(4), 
                                  				fees_attributes: [service_fee])
                                    
  @get_covered.billing_strategies.create!(title: 'Quarterly', enabled: true,  carrier_code: "F",
		                                      new_business: { payments: [40, 0, 0, 20, 0, 0, 20, 0, 0, 20, 0, 0], 
		                                                      payments_per_term: 4, remainder_added_to_deposit: true },
		                                      carrier: @crum, policy_type: PolicyType.find(4), 
                                  				fees_attributes: [service_fee])
                                    
  @get_covered.billing_strategies.create!(title: 'Annually', enabled: true,  carrier_code: "A",
		                                      new_business: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 
		                                                      payments_per_term: 1, remainder_added_to_deposit: true },
		                                      carrier: @crum, policy_type: PolicyType.find(4), 
                                  				fees_attributes: [service_fee])
                                    
  @get_covered.billing_strategies.create!(title: 'Monthly', enabled: true, carrier_code: nil,
  		                                      new_business: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], 
  		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
  		                                      carrier: @pensio, policy_type: PolicyType.find(5), 
                                    				fees_attributes: [service_fee]) 
                                            
  # MSI / Get Covered Billing & Commission Strategies
  unless ENV['skip_msi']
    @get_covered.billing_strategies.create!(title: 'Annually', enabled: true, carrier: @msi, 
                                              policy_type: PolicyType.find(1), carrier_code: "Annual",
                                              new_business: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 
                                                              payments_per_term: 1, remainder_added_to_deposit: true }, 
                                              fees_attributes: [service_fee])
                                      
    @get_covered.billing_strategies.create!(title: 'Bi-Annually', enabled: true,  carrier_code: "SemiAnnual",
                                              new_business: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], #[50, 0, 0, 0, 0, 0, 50, 0, 0, 0, 0, 0], 
                                                              payments_per_term: 2, remainder_added_to_deposit: true },
                                              carrier: @msi, policy_type: PolicyType.find(1), 
                                              fees_attributes: [service_fee])
                                      
    @get_covered.billing_strategies.create!(title: 'Quarterly', enabled: true,  carrier_code: "Quarterly",
                                              new_business: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], #[25, 0, 0, 25, 0, 0, 25, 0, 0, 25, 0, 0], 
                                                              payments_per_term: 4, remainder_added_to_deposit: true },
                                              carrier: @msi, policy_type: PolicyType.find(1), 
                                              fees_attributes: [service_fee])
    # MOOSE WARNING: docs say 20% down payment and 10 monthly payments... wut sense dis make?
    @get_covered.billing_strategies.create!(title: 'Monthly', enabled: true, carrier_code: "Monthly",
                                              new_business: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], #[22.01, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09], 
                                                              payments_per_term: 12, remainder_added_to_deposit: true },
                                              renewal: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], #[8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], 
                                                              payments_per_term: 12, remainder_added_to_deposit: true },
                                              carrier: @msi, policy_type: PolicyType.find(1), 
                                              fees_attributes: [service_fee])
  end
else
  pp @get_covered.errors
end

##
# Set Up Cambridge
#

@cambridge_agencies = [
  {
  	title: "Cambridge QBE", 
  	enabled: true, 
  	whitelabel: true, 
  	tos_accepted: true, 
  	tos_accepted_at: Time.current, 
  	tos_acceptance_ip: nil, 
  	verified: false, 
  	stripe_id: nil, 
  	master_agency: false,
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
  	]
	},
	{
  	title: "Cambridge GC", 
  	enabled: true, 
  	whitelabel: true, 
  	tos_accepted: true, 
  	tos_accepted_at: Time.current, 
  	tos_acceptance_ip: nil, 
  	verified: false, 
  	stripe_id: nil, 
  	master_agency: false,
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
  	]
  	
	}  
]

@cambridge_agencies.each do |ca|
  cambridge_agency = Agency.new(ca)
  if cambridge_agency.save
    
    site_staff = [
      { email: "dylan@#{ cambridge_agency.slug }.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: cambridge_agency, 
        profile_attributes: { first_name: 'Dylan', last_name: 'Gaines', job_title: 'Chief Technical Officer', birth_date: '04-01-1989'.to_date }},
      { email: "brandon@#{ cambridge_agency.slug }.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: cambridge_agency, 
        profile_attributes: { first_name: 'Brandon', last_name: 'Tobman', job_title: 'Chief Executive Officer', birth_date: '18-11-1983'.to_date }},
      { email: "baha@#{ cambridge_agency.slug }.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: cambridge_agency, 
        profile_attributes: { first_name: 'Baha', last_name: 'Sagadiev'}}
    ]
    
    site_staff.each do |staff|
      SeedFunctions.adduser(Staff, staff)
    end
  
    cambridge_agency.carriers << @qbe 
    cambridge_agency.carriers << @qbe_specialty
    
    qbe_agency_id = cambridge_agency.title == "Cambridge QBE" ? "CAMBQBE" : "CAMBGC"
    
    CarrierAgency.where(agency_id: cambridge_agency.id, carrier_id: @qbe.id).take
                 .update(external_carrier_id: qbe_agency_id)
  
    cambridge_agency.carriers.each do |carrier|

      commission_strategy = ::CommissionStrategy.create!(
        title: "#{cambridge_agency.title} / #{carrier.title} Commission",
        percentage: 25,
        recipient: cambridge_agency,
        commission_strategy: ::CommissionStrategy.where(recipient: carrier, commission_strategy_id: nil).take
      )
    
    	51.times do |state|
    		
    		@policy_type = nil
    		@fee_amount = nil
    		
    		if carrier.id == 1
    			@policy_type = PolicyType.find(1)
    			@fee_amount = 4500
    		elsif carrier.id == 2
    			@policy_type = PolicyType.find(2)
    		end
    		
    	  available = state == 0 || state == 11 ? false : true # we dont do business in Alaska (0) and Hawaii (11)
    	  authorization = CarrierAgencyAuthorization.create(state: state, 
    	  																									available: available, 
    	  																									carrier_agency: CarrierAgency.where(carrier: carrier, agency: cambridge_agency).take, 
    	  																									policy_type: @policy_type,
                                                          commission_strategy: commission_strategy)
    	  Fee.create(title: "Service Fee", 
    	  					 type: :MISC, 
    	  					 per_payment: false,
    	  					 amortize: false, 
    	  					 amount: @fee_amount, 
    	  					 amount_type: :FLAT, 
    	  					 enabled: true, 
    	  					 assignable: authorization, 
    	  					 ownerable: cambridge_agency) unless @fee_amount.nil?
    	end	
    end 
    
    cambridge_agency.billing_strategies.create!(title: 'Annually', enabled: true, carrier: @qbe, carrier_code: "FL",
      		                                      new_business: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 
      		                                                      payments_per_term: 1, remainder_added_to_deposit: true }, 
                                      				  policy_type: PolicyType.find(1))
                                      
    cambridge_agency.billing_strategies.create!(title: 'Bi-Annually', enabled: true, carrier_code: "SA", 
      		                                      new_business: { payments: [50, 0, 0, 0, 0, 0, 50, 0, 0, 0, 0, 0], 
      		                                                      payments_per_term: 2, remainder_added_to_deposit: true },
      		                                      carrier: @qbe, policy_type: PolicyType.find(1))
                                      
    cambridge_agency.billing_strategies.create!(title: 'Quarterly', enabled: true, carrier_code: "QT", 
      		                                      new_business: { payments: [25, 0, 0, 25, 0, 0, 25, 0, 0, 25, 0, 0], 
      		                                                      payments_per_term: 4, remainder_added_to_deposit: true },
      		                                      carrier: @qbe, policy_type: PolicyType.find(1))
                                      
    cambridge_agency.billing_strategies.create!(title: 'Monthly', enabled: true, carrier_code: "QBE_MoRe", 
      		                                      new_business: { payments: [22.01, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09], 
      		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
      		                                      renewal: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], 
      		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
      		                                      carrier: @qbe, policy_type: PolicyType.find(1))    
       
  else
    pp cambridge_agency.errors
  end
end


##
# Set Up Cambridge
#

@get_covered_agencies = [
  {
  	title: "Get Covered 002", 
  	enabled: true, 
  	whitelabel: true, 
  	tos_accepted: true, 
  	tos_accepted_at: Time.current, 
  	tos_acceptance_ip: nil, 
  	verified: false, 
  	stripe_id: nil, 
  	master_agency: false,
    agency: @get_covered,
  	addresses_attributes: [
  		{
  			street_number: "265",
  			street_name: "Canal St",
  			street_two: "#205",
  			city: "New York",
  			state: "NY",
  			county: "NEW YORK",
  			zip_code: "10013",
  			primary: true
  		}
  	]
	},
	{
  	title: "Get Covered 011", 
  	enabled: true, 
  	whitelabel: true, 
  	tos_accepted: true, 
  	tos_accepted_at: Time.current, 
  	tos_acceptance_ip: nil, 
  	verified: false, 
  	stripe_id: nil, 
  	master_agency: false,
    agency: @get_covered,
  	addresses_attributes: [
  		{
  			street_number: "265",
  			street_name: "Canal St",
  			street_two: "#205",
  			city: "New York",
  			state: "NY",
  			county: "NEW YORK",
  			zip_code: "10013",
  			primary: true
  		}
  	]
  	
	}  
]

@get_covered_agencies.each do |gca|
  gc_qbesub_agency = Agency.new(gca)
  if gc_qbesub_agency.save
    
    site_staff = [
      { email: "dylan@#{ gc_qbesub_agency.slug }.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: gc_qbesub_agency, 
        profile_attributes: { first_name: 'Dylan', last_name: 'Gaines', job_title: 'Chief Technical Officer', birth_date: '04-01-1989'.to_date }},
      { email: "brandon@#{ gc_qbesub_agency.slug }.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: gc_qbesub_agency, 
        profile_attributes: { first_name: 'Brandon', last_name: 'Tobman', job_title: 'Chief Executive Officer', birth_date: '18-11-1983'.to_date }},
      { email: "baha@#{ gc_qbesub_agency.slug }.com", password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: gc_qbesub_agency, 
        profile_attributes: { first_name: 'Baha', last_name: 'Sagadiev'}}
    ]
    
    site_staff.each do |staff|
      SeedFunctions.adduser(Staff, staff)
    end
  
    gc_qbesub_agency.carriers << @qbe 
    gc_qbesub_agency.carriers << @qbe_specialty
    
    qbe_agency_id = gc_qbesub_agency.title == "Get Covered 002" ? "Get002" : "Get011"
    
    CarrierAgency.where(agency_id: gc_qbesub_agency.id, carrier_id: @qbe.id).take
                 .update(external_carrier_id: qbe_agency_id)
  
    gc_qbesub_agency.carriers.each do |carrier|

      parent_commission_strategy = ::CommissionStrategy.references(:commission_strategies).includes(:commission_strategy).where(recipient: @get_covered, commission_strategies_commission_strategies: { recipient_type: "Carrier", recipient_id: carrier.id, commission_strategy_id: nil }).take
      commission_strategy = ::CommissionStrategy.create!(
        title: "#{gc_qbesub_agency.title} / #{carrier.title} Commission",
        percentage: parent_commission_strategy.percentage - 5,
        recipient: gc_qbesub_agency,
        commission_strategy: parent_commission_strategy
      )
    
    	51.times do |state|
    		
    		@policy_type = nil
    		@fee_amount = nil
    		
    		if carrier.id == 1
    			@policy_type = PolicyType.find(1)
    			@fee_amount = 4500
    		elsif carrier.id == 2
    			@policy_type = PolicyType.find(2)
    		end
    		
    	  available = state == 0 || state == 11 ? false : true # we dont do business in Alaska (0) and Hawaii (11)
    	  authorization = CarrierAgencyAuthorization.create(state: state, 
    	  																									available: available, 
    	  																									carrier_agency: CarrierAgency.where(carrier: carrier, agency: gc_qbesub_agency).take, 
    	  																									policy_type: @policy_type,
                                                          commission_strategy: commission_strategy)
    	  Fee.create(title: "Service Fee", 
    	  					 type: :MISC, 
    	  					 per_payment: false,
    	  					 amortize: false, 
    	  					 amount: @fee_amount, 
    	  					 amount_type: :FLAT, 
    	  					 enabled: true, 
    	  					 assignable: authorization, 
    	  					 ownerable: gc_qbesub_agency) unless @fee_amount.nil?
    	end	
    end 
    
    gc_qbesub_agency.billing_strategies.create!(title: 'Annually', enabled: true, carrier: @qbe, 
      		                                      new_business: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 
      		                                                      payments_per_term: 1, remainder_added_to_deposit: true },
                                      				   carrier_code: "FL", policy_type: PolicyType.find(1))
                                      
    gc_qbesub_agency.billing_strategies.create!(title: 'Bi-Annually', enabled: true, carrier_code: "SA",
      		                                      new_business: { payments: [50, 0, 0, 0, 0, 0, 50, 0, 0, 0, 0, 0], 
      		                                                      payments_per_term: 2, remainder_added_to_deposit: true },
      		                                      carrier: @qbe, policy_type: PolicyType.find(1))
                                      
    gc_qbesub_agency.billing_strategies.create!(title: 'Quarterly', enabled: true, carrier_code: "QT", 
      		                                      new_business: { payments: [25, 0, 0, 25, 0, 0, 25, 0, 0, 25, 0, 0], 
      		                                                      payments_per_term: 4, remainder_added_to_deposit: true },
      		                                      carrier: @qbe, policy_type: PolicyType.find(1))
                                      
    gc_qbesub_agency.billing_strategies.create!(title: 'Monthly', enabled: true, carrier_code: "QBE_MoRe", 
      		                                      new_business: { payments: [22.01, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09], 
      		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
      		                                      renewal: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], 
      		                                                      payments_per_term: 12, remainder_added_to_deposit: true },
      		                                      carrier: @qbe, policy_type: PolicyType.find(1))
       
  else
    pp gc_qbesub_agency.errors
  end
end
