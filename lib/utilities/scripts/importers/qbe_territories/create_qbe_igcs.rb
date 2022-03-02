



def get_territories(territories_file = 'lib/utilities/scripts/importers/qbe_territories/territories.csv', addresses_file = 'lib/utilities/scripts/importers/qbe_territories/sample_addresses.csv')

  territories = {}

  ####### BUILD TERRITORIES ########

  lines = Roo::Spreadsheet.open(Rails.root.join(territories_file).to_s)
  n = 2
  line = lines.row(n)
  while !line[0].blank?
    state = line[1].strip
    territory = line[2].strip
    
    territories[state] ||= {}
    cur_territory = (territories[state][territory] ||= { counties: [], zip_codes: [], cities: [], sample: nil })
    
    if state == "FL"
      county = line[9].strip
      
      cur_territory[:counties].push(county)
    elsif state == "NC"
      zip_code = line[6].strip
      city = line[7].strip
      county = line[9].strip
    
      cur_territory[:zip_codes].push(zip_code)
      cur_territory[:counties].push(county)
      cur_territory[:cities].push(city)
    else
      zip_code = line[6].strip
      
      cur_territory[:zip_codes].push(zip_code)
    end
  end

  ###### BUILD SAMPLE ADDRESSES #######

  lines = Roo::Spreadsheet.open(Rails.root.join(addresses_file).to_s)
  n = 2
  line = lines.row(n)
  done = {}
  while !line[0].blank?
    state = line[1].strip
    territory = line[3].strip
    next if done[state]&.[](territory)
    territories[state][territory][:sample] = "#{line[7].strip}, #{line[4].strip}, #{state} #{line[6].strip}" # addr city state zip
    (done[state] ||= {})[territory] = true
  end


  ####### ASSIGN TERRITORY THING TO GLOBAL #######
  $territories = territories
  return nil
end



####### GRAB EM GOOD #########

def build_igcs(territories)
  success = false
  ActiveRecord::Base.transaction do
    territories.each do |state, ters|
      ters.each do |code, data|
        sample = ::Insurable.get_or_create(**{
          address: data[:sample],
          unit: false,
          create_if_ambiguous: true,
          disallow_creation: false,
          communities_only: true
        }.compact)
        if sample.class != ::Insurable
          throw "OH MY GOD THE SAMPLE FAILED: #{state}, #{code} SAMPLE WITH ADDRESS #{data[:sample]} RETURNED #{sample.to_s}"
        end
        ::InsurableGeographicalCategory.create!(
          state: state,
          counties: data[:counties],
          zip_codes: data[:zip_codes],
          cities: data[:cities],
          special_usage: 'qbe_ho4',
          insurable: sample,
          special_designation: "#{state}_#{code}",
          special_settings: sample.get_qbe_traits(force_defaults: true)
        )
      end
    end
    success = true
  end
  puts "DONE BUILDING IGCS. SUCCESS STATUS: #{success ? "TRUE" : "FALSE"}"
end
