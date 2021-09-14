require './db/seeds/functions'
require 'faker'
require 'socket'

if !Carrier.where(id: 5).take.nil?
  puts "MSI CARRIER ALREADY EXISTS! NO NO NO!"
  exit
end

# setup.rb equivalent


carrier = Carrier.create({
  title: "Millennial Services Insurance",
  integration_designation: 'msi',
  syncable: false, 
  rateable: true, 
  quotable: true, 
  bindable: true, 
  verifiable: false, 
  enabled: true
})

puts "Initializing carrier #5..."

@get_covered = Agency.where(master_agency: true).take
carrier.access_tokens.create!


# Get Residential (HO4) Policy Type
policy_type = PolicyType.find(1)

# MSI Insurable Type for Residential Communities
carrier_insurable_type = CarrierInsurableType.create!(carrier: carrier, insurable_type: InsurableType.find(1),
                                                      enabled: true, profile_traits: {
                                                        "professionally_managed": true,
                                                        "professionally_managed_year": nil,
                                                        "construction_year": nil,
                                                        "gated": false
                                                      },
                                                      profile_data: {
                                                        "address_corrected": false,
                                                        "address_correction_data": {},
                                                        "address_correction_failed": false,
                                                        "address_correction_errors": nil,
                                                        "registered_with_msi": false,
                                                        "registered_with_msi_on": nil,
                                                        "msi_external_id": nil
                                                      })
# MSI Insurable Type for Residential units
carrier_insurable_type = CarrierInsurableType.create!(carrier: carrier, insurable_type: InsurableType.find(4), enabled: true)
# Residential Unit Policy Type
carrier_policy_type = CarrierPolicyType.create!(
  carrier: carrier,
  policy_type: policy_type,
  application_required: true,
  commission_strategy_attributes: { recipient: @get_covered, percentage: 30 },
  application_fields: [
    {
      title: "Number of Insured",
      answer_type: "INTEGER",
      default_answer: 1,
      value: 1,
      options: [1, 2, 3, 4, 5, 6, 7, 8]
    }	      																											
  ]
)

# Set up MSI InsurableRateConfigurations
msis = MsiService.new
# IRC for US
igc = ::InsurableGeographicalCategory.get_for(state: nil)
irc = msis.extract_insurable_rate_configuration(nil,
  configurer: carrier,
  configurable: igc,
  carrier_insurable_type: carrier_insurable_type,
  use_default_rules_for: 'USA'
)
irc.save!
# IRCs for the various states (and special counties)
::InsurableGeographicalCategory::US_STATE_CODES.each do |state, state_code|
  # make carrier IGC for this state
  igc = ::InsurableGeographicalCategory.get_for(state: state)
  # grab rates from MSI for this state
  result = msis.build_request(:get_product_definition,
    effective_date: Time.current.to_date + 2.days,
    state: state
  )
  unless result
    pp msis.errors
    puts "!!!!!MSI GET RATES FAILURE (#{state})!!!!!"
    exit
  end
  event = ::Event.new(
    eventable: igc,
    verb: 'post',
    format: 'xml',
    interface: 'REST',
    endpoint: msis.endpoint_for(:get_product_definition),
    process: 'msi_get_product_definition'
  )
  event.request = msis.compiled_rxml
  event.save!
  event.started = Time.now
  result = msis.call
  event.completed = Time.now     
  event.response = result[:data]
  event.status = result[:error] ? 'error' : 'success'
  event.save!
  if result[:error]
    pp result[:response]&.parsed_response
    puts ""
    puts "!!!!!MSI GET RATES FAILURE (#{state})!!!!!"
    exit
  end
  # build IRC for this state
  irc = msis.extract_insurable_rate_configuration(result[:data],
    configurer: carrier,
    configurable: igc,
    carrier_insurable_type: carrier_insurable_type,
    use_default_rules_for: state
  )
  irc.save!
  # build county IRCs if needed
  if state.to_s == 'GA'
    igc = ::InsurableGeographicalCategory.get_for(state: state, counties: ['Bryan', 'Camden', 'Chatham', 'Glynn', 'Liberty', 'McIntosh'])
    irc = msis.extract_insurable_rate_configuration(nil,
      configurer: carrier,
      configurable: igc,
      carrier_insurable_type: carrier_insurable_type,
      use_default_rules_for: 'GA_COUNTIES'
    )
    irc.save!
  end
end


# Set policy type from if else block above
carrier_policy_type.policy_type = policy_type

if carrier_policy_type.save()
  51.times do |state|
    available = state == 0 || state == 11 ? false : true
    carrier_policy_availability = CarrierPolicyTypeAvailability.create(state: state, available: available, carrier_policy_type: carrier_policy_type)
  end      
else
  pp carrier_policy_type.errors
end


# AGENCY stuff (agency.rb equivalent)

@msi = Carrier.find(5);          # Residential Carrier
@get_covered = Agency.where(master_agency: true).take
@get_covered.carriers << @msi

carrier = @msi


::CarrierAgency.create!(agency: @get_covered, carrier: carrier, carrier_agency_policy_types_attributes: carrier.carrier_policy_types.map do |cpt|
  {
    policy_type_id: cpt.policy_type_id # no need to specify commission percentage since for GC the CarrierPolicyType has the GC commission already & will be inherited
  }
end)


# MSI / Get Covered Billing & Commission Strategies

@get_covered.billing_strategies.create!(title: 'Annually', enabled: true, carrier: @msi, 
                                          policy_type: PolicyType.find(1), carrier_code: "Annual",
                                          fees_attributes: [])
                                  
@get_covered.billing_strategies.create!(title: 'Bi-Annually', enabled: true,  carrier_code: "SemiAnnual",
                                          new_business: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], #[50, 0, 0, 0, 0, 0, 50, 0, 0, 0, 0, 0], 
                                                          payments_per_term: 2, remainder_added_to_deposit: true },
                                          carrier: @msi, policy_type: PolicyType.find(1), 
                                          fees_attributes: [])
                                  
@get_covered.billing_strategies.create!(title: 'Quarterly', enabled: true,  carrier_code: "Quarterly",
                                          new_business: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], #[25, 0, 0, 25, 0, 0, 25, 0, 0, 25, 0, 0], 
                                                          payments_per_term: 4, remainder_added_to_deposit: true },
                                          carrier: @msi, policy_type: PolicyType.find(1), 
                                          fees_attributes: [])
# MOOSE WARNING: docs say 20% down payment and 10 monthly payments... wut sense dis make?
@get_covered.billing_strategies.create!(title: 'Monthly', enabled: true, carrier_code: "Monthly",
                                          new_business: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], #[22.01, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09], 
                                                          payments_per_term: 12, remainder_added_to_deposit: true },
                                          renewal: { payments: [100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], #[8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], 
                                                          payments_per_term: 12, remainder_added_to_deposit: true },
                                          carrier: @msi, policy_type: PolicyType.find(1), 
                                          fees_attributes: [])


# INSURABLES (insurable-residential.rb equivalent)
unless ENV['base_only'] # UNLESS BASE ONLY

@created_communities = []

 @addresses = [{
  street_number: "1304",
  street_name: "University City Blvd",
  city: "Blacksburg",
  county: "MONTGOMERY",
  state: "VA",
  zip_code: "24060",
  plus_four: "2904",
  primary: true
},
{
  street_number: "2501",
  street_name: "Veterans Memorial Pkwy",
  city: "Tuscaloosa",
  county: "TUSCALOOSA",
  state: "AL",
  zip_code: "35404",
  plus_four: "4147",
  primary: true
},
{
  street_number: "1725",
  street_name: "Harvey Mitchell Pkwy S",
  city: "College Station",
  county: "BRAZOS",
  state: "TX",
  zip_code: "77840",
  plus_four: "6312",
  primary: true
}]

@building_name_options = ['Estates', 'Gardens', 'Homes', 'Place']
@residential_community_insurable_type = InsurableType.find(1)
@residential_unit_insurable_type = InsurableType.find(4)
@accounts = Carrier.find(5).agencies.map{|ag| ag.accounts.to_a }.flatten.map{|acct| { account: acct, assignments: 0 } }

@addresses.each do |addr|

  args = {
    policy_type_id: 1,
    state: addr[:state],
    zip_code: addr[:zip_code],
    plus_four: addr[:plus_four]
  }
  # assign to the account with the least assignments so far that will accept it
  @accounts.sort{|a,b| a[:assignments] <=> b[:assignments] }.each do |account_data|
    # extract account and setup flag to tell us when we successfuly assigned it
    account = account_data[:account]
    assigned = false
    carrier_assignment_id = 5
    args[:carrier_id] = 5

    if account.agency.offers_policy_type_in_region(args)
      @community = account.insurables.new(title: "#{Faker::Movies::LordOfTheRings.location} #{@building_name_options[rand(0..3)]}", 
                                          insurable_type: @residential_community_insurable_type, 
                                          enabled: true, category: 'property',
                                          addresses_attributes: [ addr ])			
      unless @community.save
        pp @community.errors
      else
        assigned = true
        # create assignments (with pointless random ordering)
        account.staff.order("RANDOM()").each do |staff|
          Assignment.create!(staff: staff, assignable: @community)
        end
        # build profile
        @community.create_carrier_profile(5)
        @profile = @community.carrier_profile(5)
        @profile.traits['professionally_manged'] = (rand(1..100) == 0 ? false : true)
        @profile.traits['professionally_managed_year'] = @profile.traits['professionally_manged'] ? (Time.current.to_date - rand(0..20).years).year : nil
        @profile.traits['construction_year'] = (@profile.traits['professionally_managed_year'] || Time.current.to_date.year) - rand(1..15)
        @profile.traits['gated'] = [false, true][rand(0..1)]
        unless @profile.save()
          puts "\nCommunity Carrier Profile Save Error\n\n"
          pp @profile.errors.to_json
        end
        @created_communities.push(@community)
        # build floors
        units_per_floor = rand(5..10)
        floors = rand(1..4).to_i
        floors.times do |floor|
          floor_id = (floor + 1) * 100
          units_per_floor.times do |unit_num|
            mailing_id = floor_id + (unit_num + 1)
            @unit = @community.insurables.new(title: mailing_id, insurable_type: @residential_unit_insurable_type,
                                                 enabled: true, category: 'property', account: account, preferred_ho4: true)
            if @unit.save
              @unit.create_carrier_profile(5)
            else
              puts "\nUnit Save Error\n\n"
              pp @unit.errors.to_json
            end                
          end
        end
        # register with msi
        errors = @community.register_with_msi
        unless errors.blank?
          puts "\nCommunity MSI Registration Error"
          errors.each do |err|
            puts "  #{err}"
          end
          puts "\n\n"
        end
      end	
    end
  
    # increment if we managed to assign it
    if assigned
      account_data[:assignments] += 1
      break
    end
  end

end


### USERS (user.rb equivalent)

@created_leases = []
@residential_units = @created_communities.map{|c| c.units.where(insurable_type_id: 4).to_a }.flatten

@residential_units.each do |unit|
  
  # Create a 66% Occupancy Rate
  occupied_chance = rand(0..100)
  if occupied_chance > 33
    
    tenant_count = rand(1..5)
		start_date = (Time.now + rand(2..16).days)
    end_date = start_date + 1.years
    
    @lease = unit.leases.new(start_date: start_date, end_date: end_date, lease_type: LeaseType.find(1), account: unit.account)
    
    if @lease.save
	  	@created_leases.push(@lease)
	  	tenant_count.times do |tc|
		  	
	      loop do
			  	name = {
				  	:first => Faker::Name.first_name,
				  	:last => Faker::Name.last_name
			  	}
			  	
			  	email_providers = ['gmail', 'yahoo', 'msn', 'outlook']
			  	email = "#{ name[:first].downcase }#{ name[:last].downcase }@#{email_providers[rand(0..3)]}.com"
	        
	        unless ::User.exists?(:email => email)
				  	user = ::User.new(email: email, password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234',
				  													     profile_attributes: { first_name: name[:first], 
					  													     										 last_name: name[:last], 
					  													     										 birth_date: SeedFunctions.time_rand(Time.local(1955, 1, 1), Time.local(1991, 1, 1)) })		
						if user.save
							@lease.users << user
	        	end
	        	
	        	break        
		      end

	      end
		  end
		  
		  @lease.primary_user().attach_payment_source("tok_visa", true)
		else
		
			pp @lease.errors
		    
	  end
    
    
  end
end

#puts "\nOccupancy Rate: #{ (Lease.count.to_f / Insurable.residential_units.count) * 100 }%\n\n"


### POLICY RESIDENTIAL (policy-residential.rb equivalent)

@leases = @created_leases
@msi_id = 5
@max_msi_coverage_selection_iterations = 5


@msi_test_card_data = {
  1257 => {
    token: "9495846215171111",
    card_info: {
      CreditCardInfo: {
        CardHolderName: "Payment Test",
        CardExpirationDate: "0125",
        CardType: "Visa",
        CreditCardLast4Digits: "1111",
        Addr: {
          Addr1: "2601 Lakeshore Dr",
          Addr2: nil,
          City: "Flower Mound",
          StateProvCd: "TX",
          PostalCode: "75028"
        }
      }
    }
  },
  47 => {
    token: "2738374128080004",
    card_info: {
      CreditCardInfo: {
        CardHolderName: "Payment Testing",
        CardExpirationDate: "0226",
        CardType: "Mastercard",
        CreditCardLast4Digits: "0004",
        Addr: {
          Addr1: "1414 Northeast Campus Parkway",
          Addr2: nil,
          City: "Seattle",
          StateProvCd: "WA",
          PostalCode: "98195"
        }
      }
    }
  }
}




@leases.each do |lease|
# 	if rand(0..100) > 33 # Create a 66% Coverage Rate

  if !lease.insurable.carrier_profile(@msi_id).nil?
    # grab useful variables & set up application
    carrier_id = @msi_id
		policy_type = PolicyType.find(1)
		billing_strategy = BillingStrategy.where(agency: lease.account.agency, policy_type: policy_type, carrier_id: carrier_id)
		                                  .order("RANDOM()")
		                                  .take
		application = PolicyApplication.new(
			effective_date: lease.start_date,
			expiration_date: lease.end_date,
			carrier_id: carrier_id,
			policy_type: policy_type,
			billing_strategy: billing_strategy,
			agency: lease.account.agency,
			account: lease.account
		)
		# set application fields & add insurable
		application.build_from_carrier_policy_type()
		application.fields[0]["value"] = lease.users.count
		application.insurables << lease.insurable
    # add lease users
    primary_user = lease.primary_user()
    lease_users = lease.users.where.not(id: primary_user.id)
    application.users << primary_user
    lease_users.each { |u| application.users << u }
    # prepare to choose rates
    community = lease.insurable.parent_community
    cip = CarrierInsurableProfile.where(carrier_id: carrier_id, insurable_id: community.id).take
    effective_date = application.effective_date
    additional_insured_count = application.users.count - 1
    cpt = CarrierPolicyType.where(carrier_id: carrier_id, policy_type_id: 1).take
    # choose rates
    coverage_options = []
    coverage_selections = []
    result = { valid: false }
    iteration = 0
    max_iters = @max_msi_coverage_selection_iterations
    loop do
      iteration += 1
      result = ::InsurableRateConfiguration.get_coverage_options(
        cpt, community, coverage_selections, effective_date, additional_insured_count, billing_strategy,
        perform_estimate: false
      )
      if result[:valid]
        break
      elsif iteration > max_iters
        application.update(status: 'quote_failed')
        puts "Application ID: #{ application.id } | Application Status: #{ application.status } | Failed to find valid coverage options selection by #{max_iters}th iteration!!!"
        break
      elsif !result[:coverage_options].blank?
        coverage_selections = ::InsurableRateConfiguration.automatically_select_options(result[:coverage_options], coverage_selections)
      else
        application.update(status: 'quote_failed')
        puts "Application ID: #{ application.id } | Application Status: #{ application.status } | Failed to retrieve any coverage options!!!"
        break
      end
    end
    # continue creating policy
    if result[:valid]
      # mark application complete and save it
      application.coverage_selections = coverage_selections.select{|cs| cs['selection'] }
      application.status = 'complete'
      if !application.save
        pp application.errors
        puts "Application ID: 'NONE' | Application Status: #{ application.status } | Failed to save application!!!"
      else
        # create quote
        quote = application.estimate
        #puts "Got quote #{quote.class.name} : #{quote.respond_to?(:id) ? quote.id : 'no id'}"
        application.quote(quote.id)
        quote.reload
        if quote.id.nil? || quote.status != 'quoted'
          puts quote.errors.to_h.to_s unless quote.id
          puts "Application ID: #{ application.id } | Application Status: #{ application.status } | Quote ID: #{quote.id} | Quote Status: #{ quote.status }"
        else
          # grab test payment data
          test_payment_data = {
            'payment_method' => 'card',
            'payment_info' => @msi_test_card_data[quote.carrier_payment_data['product_id'].to_i][:card_info],
            'payment_token' => @msi_test_card_data[quote.carrier_payment_data['product_id'].to_i][:token],
          }
          # accept quote
          acceptance = quote.accept(bind_params: test_payment_data)
          if !quote.reload.policy.nil?
            # print a celebratory message
            premium = quote.policy_premium
            policy = quote.policy
            message = "POLICY #{ policy.number } has been #{ policy.status.humanize }\n"
            message += "Application ID: #{ application.id } | Application Status: #{ application.status } | Quote Status: #{ quote.status }\n" 
            message += "Premium Base: $#{ '%.2f' % (premium.base.to_f / 100) } | Taxes: $#{ '%.2f' % (premium.taxes.to_f / 100) } | Fees: $#{ '%.2f' % (premium.total_fees.to_f / 100) } | Total: $#{ '%.2f' % (premium.total.to_f / 100) }"
            puts message
          else
            puts "Application ID: #{ application.id } | Application Status: #{ application.status } | Quote Status: #{ quote.status }"
          end  
        end
      end
    end
    
    
    
    
    
  # end msi
  end
# 	end	
end


end # END UNLESS BASE ONLY
