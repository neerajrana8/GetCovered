require './db/seeds/functions'
require 'faker'
require 'socket'

ActiveRecord::Base.transaction do

@created_communities = {}
@created_units = []

@residential_community_insurable_type = InsurableType.find(1)
@residential_unit_insurable_type = InsurableType.find(4)
@succeeded = false

# create communities/units from spreadsheet
puts "Importing properties from spreadsheet..."
lines = Roo::Spreadsheet.open(Rails.root.join('lib/utilities/scripts/importers/bandb/test.csv').to_s)
n = 2
line = lines.row(n)
while !line[0].blank?
  address = Address.from_string("#{line[2].strip.titleize}, #{line[4].strip.titleize}, #{line[6].strip.upcase} #{line[7].strip.split("-")[0]}")
  # get or create community
  community = @created_communities[address.full]
  if community.nil?
    # create community
    community = ::Insurable.new({
      account_id: line[0].to_i,
      title: address.combined_street_address,
      insurable_type: @residential_community_insurable_type, 
      enabled: true, category: 'property',
      preferred_ho4: true,
      addresses: [ address ]
    })
    unless community.save
      puts "Failed to save community on line #{n}, error #{community.errors.to_h.to_s}"
      raise ActiveRecord::Rollback
    end
    # create profile
    community.create_carrier_profile(5)
    profile = community.carrier_profile(5)
    profile.traits['professionally_manged'] = true
    profile.traits['construction_year'] = line[8].to_i unless line[8].blank? # professionally_managed_year and gated are unknown...
    profile.save
    @created_communities[address.full] = community
  end
  # handle unit situation
  unless line[3].blank?
    unit_number = line[3].gsub(/\D/, '')
    unit = ::Insurable.new(
      insurable: community,
      title: unit_number,
      insurable_type: @residential_unit_insurable_type,
      enabled: true, category: 'property',
      preferred_ho4: true,
      account_id: community.account_id
    )
    unless unit.save
      puts "Failed to save unit on line #{n}, error #{unit.errors.to_h.to_s}"
      raise ActiveRecord::Rollback
    end
    unit.create_carrier_profile(5)
  end
  # increment
  n += 1
  line = lines.row(n)
end

# add pseudohouses
puts "Creating pseudohouses..."
@created_communities.values.select{|cc| cc.units.count == 0 }.each do |community|
  unit_number = nil
  unit = ::Insurable.new(
    insurable: community,
    title: unit_number,
    insurable_type: @residential_unit_insurable_type,
    enabled: true, category: 'property',
    preferred_ho4: true,
    account_id: community.account_id
  )
  unless unit.save
    puts "Failed to save titleless unit for community #{community.title}, error #{unit.errors.to_h.to_s}"
    raise ActiveRecord::Rollback
  end
  unit.create_carrier_profile(5)
  @created_units.push(unit)
end

puts "Import of records successful;\n  communities: #{@created_communities.values.map{|cc| cc.id }.join(", ")}\n  units: #{@created_units.map{|cu| cu.id }.join(", ")}"


#puts "ABORTING ANYWAY!!!!"
#raise ActiveRecord::Rollback



@succeeded = true
end # end transaction

unless @succeeded
  puts "Aborted import process"
  exit
else
  #### register
  
  puts "Registering communities with MSI..."
  @successfully_registered = []
  @failures = {}
  @created_communities.values.each do |community|
    errors = community.register_with_msi
    if errors.blank?
      @successfully_registered.push(community.id)
    else
      @failures[community.id] = "Community #{community.id} registration FAILED; errors:\n  #{errors.join("\n  ")}"
    end
  end

  @failures.each do |fid, f|
    puts f
  end

  puts "Process compelete!"
  puts ""
  puts "  Successfully registered: #{@successfully_registered.join(", ")}"
  puts ""
  puts "  Failures: #{@failures.keys.join(", ")}"
end


