require './db/seeds/functions'
require 'faker'
require 'socket'

ACCOUNT_ID = 0
ACCOUNT_NAME = 1
UNIT_ADDRESS1 = 2
UNIT_ADDRESS2 = 3
UNIT_CITY = 4
UNIT_COUNTY = 5
UNIT_STATE = 6
UNIT_ZIP = 7
COMMUNITY_YEAR_BUILT = 8
COMMUNITY_NAME = 9
UNIT_DISPLAY_NAME = 10
COMMUNITY_ADDRESS1 = 11
COMMUNITY_ADDRESS2 = 12
COMMUNITY_CITY = 13
COMMUNITY_STATE = 14
COMMUNITY_ZIP = 15


puts "Preparing Platonic infrastructure..."
zipper = Proc.new{|zip| tr = zip.strip.split("-")[0]; "#{(0...(5 - tr.length)).map{|n| "0"}.join("")}#{tr}" }
errors = []
by_account = {}


puts "Reading spreadsheet..."
lines = Roo::Spreadsheet.open(Rails.root.join('lib/utilities/scripts/importers/bandb/qcom/insurables.csv').to_s)
n = 2
line = lines.row(n)
while !line[0].blank?
  # put our line into our hash
  position = (by_account[line[0].to_i] ||= { 'by_community' => {} })
  position = (position['by_community'][
    [
      line[COMMUNITY_TITLE],
      line[COMMUNITY_ADDRESS1],
      line[COMMUNITY_ADDRESS2],
      line[COMMUNITY_CITY],
      line[COMMUNITY_STATE],
      zipper.call(line[COMMUNITY_ZIP])
    ]
  ] ||= { 'line' => n, 'info' => { 'year_built' => line[COMMUNITY_YEAR_BUILT] }, 'by_building' => {}, 'units' => [] })
  if line[COMMUNITY_ADDRESS1] == line[UNIT_ADDRESS1] && line[COMMUNITY_CITY] == line[UNIT_CITY] && line[COMMUNITY_STATE] == line[UNIT_STATE] && line[COMMUNITY_ZIP] == line[UNIT_ZIP]
    position = position['units']
  else
    position = (position['by_building'][
      [
        line[UNIT_ADDRESS1],
        line[UNIT_CITY],
        line[UNIT_STATE],
        zipper.call(line[UNIT_ZIP])
      ]
    ] ||= { 'line' => n, 'units' => [] })['units']
  end
  position.push({
    'title' => line[UNIT_ADDRESS2],
    'display_title' => line[UNIT_DISPLAY_NAME]
  })
  # increment
  n += 1
  line = lines.row(n)
end


puts "Postprocessing spreadsheet data..."
by_account.values.map{|v| v['by_community'] }.each do |com, bc|
  if !bc['by_building'].blank? && !bc['units'].blank?
    bc['by_building'][
      com[1], com[3], com[4], com[5]
    ] = { 'line' => bc['line'], 'units' => bc['units'] }
    bc['units'] = []
  end
end


puts "Performing import..."
import_success = false
ActiveRecord::Base.transaction do
  by_account.each do |account_id, ba|
    ba['by_community'].each do |com, bc|
      # get the community
      community = ::Insurable.get_or_create(**{
        account_id: account_id,
        address: com.drop(1).select{|x| !x.blank? }.join(", "),
        unit: false,
        insurable_id: nil,
        create_if_ambiguous: true,
        disallow_creation: false,
        communities_only: true,
        titleless: false
      }.compact)
      if community.class != ::Insurable
        errors.push "Failed to get/create community on line #{bc['line']} (title '#{com[0]}'); get-or-create returned results of type #{community.class.name}#{community.class == ::Hash ? " contents #{community.to_s}" : ""}!"
        raise ActiveRecord::Rollback
      elsif !community.account_id.nil? && community.account_id != account_id
        errors.push "Found community on line #{bc['line']} (title '#{com[0]}'), but already belongs to account ##{community.account_id} (#{community.account&.title})!"
        raise ActiveRecord::Rollback
      elsif !community.update(account_id: account_id, confirmed: !account_id.nil?)
        errors.push "Failed to update account & preferred status for community on line #{bc['line']} (title '#{com[0]}')! Errors: #{community.errors.to_h}"
        raise ActiveRecord::Rollback
      end
      bc['in_system'] = community
      # get the buildings and units
      unless community.insurables.blank?
        errors.push "Community on line #{bc['line']} (title '#{com[0]}') already has insurables! Update the importer to add support for this situation."
        raise ActiveRecord::Rollback
      end
      # go wild
      bc['units'].each do |u|
        ::Insurable.create!(
          insurable_id: community.id,
          title: u['title'], insurable_type: 4, enabled: true, category: 'property',
          account_id: account_id, confirmed: !account_id.nil?
        )
      end
      bc['by_building'].each do |bldg, bb|
        building = ::Insurable.create!(
          insurable_id: community.id,
          title: bldg[0], insurable_type: 7, enabled: true, category: 'property',
          account_id: account_id, confirmed: !account_id.nil?
        )
        bb['units'].each do |u|
          ::Insurable.create!(
            insurable_id: building.id,
            title: u['title'], insurable_type: 4, enabled: true, category: 'property',
            account_id: account_id, confirmed: !account_id.nil?
          )
        end
      end
    end
  end
  import_success = true
### catch rollback if needed
end


if !import_success
  puts "Import failed. Errors:"
  errors.each{|x| puts "  #{x}" }
else

  puts "Import succeeded. Queueing QBE calls."
  puts "Created community ids:"
  puts "  #{by_account.values.map{|ba| ba['by_community'].values.map{|bc| bc['in_system'].id } }.flatten}"
  
  by_account.each do |account_id, ba|
    ba['by_community'].values.each do |bc|
      bc['in_system'].qbe_mark_preferred(strict: false, apply_defaults: true)
    end
  end
  puts "QBE calls queued."

end




