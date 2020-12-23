# Get Covered Insurable Seed Setup File
# file: db/seeds/insurable.rb

require 'faker'

@addresses = [
  {
    street_number: "105",
    street_name: "N Elm St",
    city: "Mahomet",
    county: "Champaign",
    state: "IL",
    zip_code: "61853",
    plus_four: "9364",
    primary: true
  },
  {
    street_number: "1514",
    street_name: "Robin St",
    city: "Auburndale",
    county: "Polk",
    state: "FL",
    zip_code: "33823",
    plus_four: "9718",
    primary: true
  },
  {
    street_number: "3201",
    street_name: "S Bentley Ave",
    city: "Los Angeles",
    county: "LOS ANGELES",
    state: "CA",
    zip_code: "90034",
    plus_four: "5203",
    primary: true
  },
  {
    street_number: "2625",
    street_name: "Townsgate Rd",
    city: "Westlake Village",
    county: "Ventura",
    state: "CA",
    zip_code: "91361",
    plus_four: "5751",
    primary: true
  },
  {
    street_number: "70",
    street_name: "Bonita Dr.",
    city: "Depew",
    county: "Erie",
    state: "NY",
    zip_code: "14043",
    plus_four: "1508",
    primary: true
  },
  {
    street_number: "1755",
    street_name: "S Glendon Ave",
    city: "Los Angeles",
    county: "LOS ANGELES",
    state: "CA",
    zip_code: "90024",
    plus_four: "6809",
    primary: true
  },
  {
    street_number: "5009",
    street_name: "Park Central Dr",
    city: "Orlando",
    county: "ORANGE",
    state: "FL",
    zip_code: "32839",
    plus_four: "5340",
    primary: true
  },
  {
    street_number: "1102",
    street_name: "Autumn Creek Way",
    city: "Manchester",
    county: "SAINT LOUIS",
    state: "MO",
    zip_code: "63088",
    plus_four: "1289",
    primary: true
  },
  {
    street_number: "240",
    street_name: "Hickory Hedge Drive",
    city: "Manchester",
    county: "SAINT LOUIS",
    state: "MO",
    zip_code: "63021",
    plus_four: "5707",
    primary: true
  },
  {
    street_number: "7111",
    street_name: "Jefferson Run Dr",
    city: "Louisville",
    county: "JEFFERSON",
    state: "KY",
    zip_code: "40228",
    plus_four: "3078",
    primary: true
  },
  {
    street_number: "13900",
    street_name: "Steelecroft Farm Lane",
    city: "Charlotte",
    county: "MECKLENBURG",
    state: "NC",
    zip_code: "28278",
    plus_four: "7493",
    primary: true
  },
  {
    street_number: "1340",
    street_name: "Washington Blvd",
    city: "Stamford",
    county: "FAIRFIELD",
    state: "CT",
    zip_code: "06902",
    plus_four: "2452",
    primary: true
  },
  {
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
  }
]

@building_name_options = ['Estates', 'Gardens', 'Homes', 'Place']
@residential_community_insurable_type = InsurableType.find(1)
@residential_unit_insurable_type = InsurableType.find(4)

@carrier_assignments = { 1 => 0, 5 => 0 }
@accounts = Account.all.to_a.map{|acct| { account: acct, assignments: 0 } }
while @addresses.length > 0
  # set up address and args
  addr = @addresses.pop
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
    # now try to assign it to the account under various carriers
    carriers_to_attempt = @carrier_assignments.to_a.sort{|a,b| a[1] <=> b[1] }.map{|ca| ca[0] }
    carriers_to_attempt.each do |carrier_assignment_id|
      args[:carrier_id] = carrier_assignment_id
      # try qbe
      if args[:carrier_id] == 1
        if account.agency.offers_policy_type_in_region(args)
          @community = account.insurables.new(title: "#{Faker::Movies::LordOfTheRings.location} #{@building_name_options[rand(0..3)]}", 
                                              insurable_type: @residential_community_insurable_type, 
                                              enabled: true, category: 'property',
                                              addresses_attributes: [ addr ])			
          if @community.save
            @carrier_assignments[args[:carrier_id]] += 1
            assigned = true
            
            account.staff
                    .order("RANDOM()")
                    .each do |staff|
                      
              Assignment.create!(staff: staff, assignable: @community)	
            end
            
            @community.create_carrier_profile(1)
            @profile = @community.carrier_profile(1)
            
            @profile.traits['construction_year'] = rand(1979..2005)
            @profile.traits['professionally_managed'] = true
            @profile.traits['professionally_managed_year'] = @profile.traits['construction_year'] + 1
            
            @profile.save()
            
            # puts "[#{ @community.title }] Accessing QBE Zip Code"
            @community.get_qbe_zip_code()
            
            # puts "[#{ @community.title }] Accessing QBE Property Info"
            @community.get_qbe_property_info()
            
            units_per_floor = rand(5..10)
            floors = rand(1..4).to_i
            
            floors.times do |floor|
              
              floor_id = (floor + 1) * 100
              
              units_per_floor.times do |unit_num|
                
                mailing_id = floor_id + (unit_num + 1)
                @unit = @community.insurables.new(title: mailing_id, insurable_type: @residential_unit_insurable_type,
                                                     enabled: true, category: 'property', account: account)
                
                if @unit.save
                  @unit.create_carrier_profile(1)
                else
                  puts "\nUnit Save Error\n\n"
                  pp @unit.errors.to_json
                end                
              end
            end
            
            @community.reset_qbe_rates(true, true)
          else	
            pp @community.errors
          end
        end
      end
      # try msi
      if args[:carrier_id] == 5
        if account.agency.offers_policy_type_in_region(args)
          @community = account.insurables.new(title: "#{Faker::Movies::LordOfTheRings.location} #{@building_name_options[rand(0..3)]}", 
                                              insurable_type: @residential_community_insurable_type, 
                                              enabled: true, category: 'property',
                                              addresses_attributes: [ addr ])			
          unless @community.save
            pp @community.errors
          else
            @carrier_assignments[args[:carrier_id]] += 1
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
            # build floors
            units_per_floor = rand(5..10)
            floors = rand(1..4).to_i
            floors.times do |floor|
              floor_id = (floor + 1) * 100
              units_per_floor.times do |unit_num|
                mailing_id = floor_id + (unit_num + 1)
                @unit = @community.insurables.new(title: mailing_id, insurable_type: @residential_unit_insurable_type,
                                                     enabled: true, category: 'property', account: account)
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
      end
    end
    # break out of the loop if we managed to assign it
    if assigned
      account_data[:assignments] += 1
      break
    end
  end
end

