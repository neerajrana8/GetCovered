require './db/seeds/functions'
require 'faker'
require 'socket'

ActiveRecord::Base.transaction do

@created_communities = {}
@created_units = []

@residential_community_insurable_type = InsurableType.find(1)
@residential_unit_insurable_type = InsurableType.find(4)
@succeeded = false

@zipper = Proc.new{|zip| tr = zip.strip.split("-")[0]; "#{(0...(5 - tr.length)).map{|n| "0"}.join("")}#{tr}" }

# create communities/units from spreadsheet
puts "Importing properties from spreadsheet..."
lines = Roo::Spreadsheet.open(Rails.root.join('lib/utilities/scripts/importers/bandb/bandb.csv').to_s)
n = 2
line = lines.row(n)
while !line[0].blank?
  address = Address.from_string("#{line[2].strip.titleize}, #{line[4].strip.titleize}, #{line[6].strip.upcase} #{@zipper.call(line[7])}")
  # get or create community
  community = ::Insurable.get_or_create(**{
    account_id: line[0].to_i,
    address: "#{line[2].strip.titleize}, #{line[4].strip.titleize}, #{line[6].strip.upcase} #{@zipper.call(line[7])}",
    unit: false,
    insurable_id: nil,
    create_if_ambiguous: true,
    disallow_creation: false,
    communities_only: true,
    titleless: false
  }.compact)
  if community.class != ::Insurable
    puts "Failed to get/create community on line #{n}, got results of type #{community.class.name}#{community.class == ::Hash ? " contents #{community.to_s}" : ""}"
    raise ActiveRecord::Rollback
  elsif !community.account.nil? && community.account.slug != 'nonpreferred-residential' && community.account.id != line[0].to_i
    puts "Found community for line #{n}, but already belongs to account #{community.account.id} (#{community.account.title})"
    raise ActiveRecord::Rollback
  elsif !community.update(account_id: line[0].to_i, preferred_ho4: false)
    puts "Failed to update account & preferred status for community for line #{n}; errors: #{community.errors.to_h.to_s}"
    raise ActiveRecord::Rollback
  end
=begin
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
=end
  # create profile
  unless community.carrier_profile(5)
    community.create_carrier_profile(5)
    profile = community.carrier_profile(5)
    profile.traits['professionally_manged'] = true
    profile.traits['construction_year'] = (line[8].blank? ? '1996' : line[8].to_i) # professionally_managed_year and gated are unknown...
    profile.save
  end
  @created_communities[community.primary_address.full] = community
  # handle unit situation
  unit = ::Insurable.get_or_create(**{
    account_id: line[0].to_i,
    address: "#{line[2].strip.titleize}, #{line[4].strip.titleize}, #{line[6].strip.upcase} #{@zipper.call(line[7])}",
    unit: line[3].blank? ? true : line[3],
    insurable_id: community.id,
    create_if_ambiguous: true,
    disallow_creation: false,
    communities_only: false,
    titleless: line[3].blank? ? true : false
  }.compact)
  if unit.class != ::Insurable
    puts "Failed to get/create unit for line #{n}, got results of type #{unit.class.name}#{unit.class == ::Hash ? " contents #{unit.to_s}" : ""}"
    raise ActiveRecord::Rollback
  elsif !unit.account.nil? && unit.account.slug != 'nonpreferred-residential' && unit.account.id != line[0].to_i
    puts "Found unit for line #{n}, but already belongs to account #{unit.account.id} (#{unit.account.title})"
    raise ActiveRecord::Rollback
  elsif !unit.update(account_id: line[0].to_i, preferred_ho4: true)
    puts "Failed to update account & preferred status for unit for line #{n}; errors: #{unit.errors.to_h.to_s}"
    raise ActiveRecord::Rollback
  end
  unless unit.carrier_profile(5)
    unit.create_carrier_profile(5)
  end
  @created_units.push(unit)
=begin
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
=end
  # increment
  n += 1
  line = lines.row(n)
end

=begin
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
=end

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
  @created_communities.values.select{|cc| !cc.carrier_profile(5)&.data&.[]('registered_with_msi') }.each do |community|
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


