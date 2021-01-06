require './db/seeds/functions'
require 'faker'
require 'socket'

# prepare useful fellows
@created_communities = []
@agency = Agency.find(1)
@account = @agency.accounts.take
@building_name_options = ['Estates', 'Gardens', 'Homes', 'Place']
@residential_community_insurable_type = InsurableType.find(1)
@residential_unit_insurable_type = InsurableType.find(4)
@addresses = []

# grab addresses from spreadsheet
addrs = Roo::Spreadsheet.open(Rails.root.join('db/seeds/data/msi_test_addresses.csv').to_s)
n = 2
addr = addrs.row(n)
while !addr[0].blank?
  splat = addr[0].strip.split(" ")
  # insert into address
  @addresses.push({
    street_number: splat[0],
    street_name: splat.drop(1).join(" "),
    city: addr[1].strip,
    state: addr[2].strip,
    zip_code: addr[3].strip,
    primary: true
  })
  # increment
  n += 1
  addr = addrs.row(n)
end

# create insurables
@addresses.each do |addr|
  # setup
  args = {
    policy_type_id: 1,
    state: addr[:state],
    zip_code: addr[:zip_code]
  }
  account = @account
  assigned = false
  carrier_assignment_id = 5
  args[:carrier_id] = 5
  # create insurable
  if account.agency.offers_policy_type_in_region(args)
    @community = account.insurables.new(title: "#{Faker::Movies::LordOfTheRings.location}-#{Time.current.to_i} #{@building_name_options[rand(0..3)]}", 
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
end


# lease/user magic

unless ENV['base_only']

@created_leases = []
@residential_units = @created_communities.map{|c| c.units.where(insurable_type_id: 4).to_a }.flatten

@residential_units.each do |unit|
  
  # Create a 15% Occupancy Rate
  occupied_chance = rand(0..100)
  if occupied_chance >= 85
    
    tenant_count = rand(1..5)
		start_date = (Time.now + rand(0..14).days)
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
	        
	        unless User.exists?(:email => email)
				  	user = User.new(email: email, password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234',
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

end # end base_only restriction
