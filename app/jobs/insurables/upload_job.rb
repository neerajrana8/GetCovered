module Insurables
  class UploadJob < ApplicationJob
    queue_as :default

    ACCOUNT_ID = 0
    ACCOUNT_NAME = 1
    UNIT_ADDRESS1 = 2
    UNIT_ADDRESS2 = 3
    UNIT_CITY = 4
    UNIT_COUNTY = 5
    UNIT_STATE = 6
    UNIT_ZIP = 7
    COMMUNITY_YEAR_BUILT = 8
    COMMUNITY_TITLE = 9
    UNIT_DISPLAY_NAME = 10
    COMMUNITY_ADDRESS1 = 11
    COMMUNITY_ADDRESS2 = 12
    COMMUNITY_CITY = 13
    COMMUNITY_STATE = 14
    COMMUNITY_ZIP = 15

    def s3_bucket
      env = Rails.env.to_sym
      aws_bucket_name = Rails.application.credentials.aws[env][:bucket]
      Aws::S3::Resource.new.bucket(aws_bucket_name)
    end

    def perform(object_name:, file:, email:)
      puts "Preparing infrastructure..."
      Rails.logger.info "Prepare o#{object_name}, email=#{email}"
      zipper = Proc.new { |zip| tr = zip.strip.split("-")[0]; "#{(0...(5 - tr.length)).map { |n| "0" }.join("")}#{tr}" }
      errors = []
      by_account = {}

      Rails.logger.info 'Loading uploaded file from aws::s3'

      File.open(file, 'wb') do |tmp_file|
        x = s3_bucket.object(object_name)
        tmp_file << x.get.body.read
      end

      puts "Reading spreadsheet..."
      lines = Roo::Spreadsheet.open(file)
      n = 2
      line = lines.row(n)

      until line[0].blank?
        # put our line into our hash
        position = (by_account[line[0].to_i] ||= { 'by_community' => {} })
        position = (position['by_community'][
          [
            line[COMMUNITY_TITLE],
            line[COMMUNITY_ADDRESS1],
            !line[COMMUNITY_ADDRESS2].blank? && (0..9).any? { |d| d.to_s == line[COMMUNITY_ADDRESS2][0] } ? "Unit #{line[COMMUNITY_ADDRESS2]}" : line[COMMUNITY_ADDRESS2],
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
                        'display_title' => line[UNIT_DISPLAY_NAME],
                        'line' => n
                      })
        # increment
        n += 1
        line = lines.row(n)
      end

      puts "Postprocessing spreadsheet data..."
      by_account.values.map { |v| v['by_community'] }.each do |x|
        x.each do |com, bc|
          if !bc['by_building'].blank? && !bc['units'].blank?
            bc['by_building'][
              [com[1], com[3], com[4], com[5]]
            ] = { 'line' => bc['line'], 'units' => bc['units'] }
            bc['units'] = []
          end
        end
      end

      Rails.logger.info "#{by_account}"
      puts "Performing import..."
      Rails.logger.info 'Perform importing...'
      import_success = false
      ActiveRecord::Base.transaction do
        by_account.each do |account_id, ba|
          ba['by_community'].each do |com, bc|
            puts "Creating community ##{bc['line']}: #{com[0]}"
            # get the community
            Rails.logger.info "Creating community... #{bc['line']}"

            community = ::Insurable.get_or_create(**(parmz = {
              account_id: account_id,
              address: com.drop(1).select { |x| !x.blank? }.join(", "),
              unit: false,
              insurable_id: nil,
              create_if_ambiguous: true,
              disallow_creation: false,
              communities_only: true,
              titleless: false,
              created_community_title: com[0]
            }.compact))
            if (community.class == ::Insurable && (community.title != com[0] || community.primary_address.street_two != com[2])) ||
              (community.class == ::Array && community.all? { |c| c.title != com[0] || c.primary_address.street_two != com[2] })
              addr = Address.from_string(com.drop(1).select { |x| !x.blank? }.join(", "))
              addr.primary = true
              community = ::Insurable.create!(
                insurable_id: nil,
                title: com[0], insurable_type_id: 1, enabled: true, category: 'property',
                account_id: account_id, confirmed: !account_id.nil?,
                addresses: [addr]
              )
            end

            if community.class != ::Insurable
              errors.push "Failed to get/create community on line #{bc['line']} (title '#{com[0]}');"
              errors.push 'get-or-create returned results of wrong type'
              errors.push "GOC parameters were: #{parmz}!"
              raise ActiveRecord::Rollback
            end

            if !community.account_id.nil? && community.account_id != account_id
              errors.push "Found community on line #{bc['line']} (title '#{com[0]}'), but already belongs to account ##{community.account_id} (#{community.account&.title})!"
              raise ActiveRecord::Rollback
            end

            if !community.update(account_id: account_id, confirmed: !account_id.nil?)
              errors.push "Failed to update account & preferred status for community on line #{bc['line']} (title '#{com[0]}')! Errors: #{community.errors.to_h}"
              raise ActiveRecord::Rollback
            end

            bc['in_system'] = community
            # get the buildings and units
            if community.insurables.blank?
              # go wild
              bc['units'].each do |u|
                puts "[com ##{bc['line']}:#{com[0]}] Creating unit #{u['line']}: #{u['title']}..."
                ::Insurable.create!(
                  insurable_id: community.id,
                  title: u['title'], insurable_type_id: 4, enabled: true, category: 'property',
                  account_id: account_id, confirmed: !account_id.nil?
                )
              end
              bc['by_building'].each do |bldg, bb|
                puts "[com ##{bc['line']}:#{com[0]}] Creating building ##{bb['line']}: #{bldg[0]}..."
                addr = Address.from_string(bldg.select { |y| !y.blank? }.join(", "))
                addr.primary = true
                building = ::Insurable.create!(
                  insurable_id: community.id,
                  title: bldg[0], insurable_type_id: 7, enabled: true, category: 'property',
                  account_id: account_id, confirmed: !account_id.nil?,
                  addresses: [addr]
                )
                bb['units'].each do |u|
                  puts "[com ##{bc['line']}:#{com[0]}][bldg ##{bb['line']}:#{bldg[0]}] Creating unit #{u['line']}: #{u['title']}..."
                  ::Insurable.create!(
                    insurable_id: building.id,
                    title: u['title'], insurable_type_id: 4, enabled: true, category: 'property',
                    account_id: account_id, confirmed: !account_id.nil?
                  )
                end
              end
            else
              # complete community import against possible duplicates
              bc['units'].each do |u|
                puts "[com ##{bc['line']}:#{com[0]}] Get-or-creating unit #{u['line']}: #{u['title']}..."
                found = community.units.find { |un| un.title == u['title'] }
                if found.nil?
                  ::Insurable.create!(
                    insurable_id: community.id,
                    title: u['title'], insurable_type_id: 4, enabled: true, category: 'property',
                    account_id: account_id, confirmed: !account_id.nil?
                  )
                else
                  if !found.account_id.nil? && found.account_id != account_id
                    errors.push "Unit on line #{u['line']} (title '#{u['title']}') already exists and belongs to the wrong account! Aborting import..."
                    raise ActiveRecord::Rollback
                  end
                  found.update!(account_id: account_id, confirmed: true, enabled: true)
                end
              end
              bc['by_building'].each do |bldg, bb|
                puts "[com ##{bc['line']}:#{com[0]}] Get-or-creating building ##{bb['line']}: #{bldg[0]}..."
                # try to find the building
                building = ::Insurable.get_or_create(
                  address: bldg.select { |y| !y.blank? }.join(", "),
                  unit: false,
                  insurable_id: community.id,
                  disallow_creation: true
                )
                building = case building
                           when ::Insurable
                             ::InsurableType::RESIDENTIAL_BUILDINGS_IDS.include?(building.insurable_type_id) ? building : nil
                           when ::Array
                             arr.find { |bildin| ::InsurableType::RESIDENTIAL_BUILDINGS_IDS.include?(bildin.insurable_type_id) }
                           else
                             nil
                           end
                if building.nil?
                  building = ::Insurable.create!(
                    insurable_id: community.id,
                    title: bldg[0], insurable_type_id: 7, enabled: true, category: 'property',
                    account_id: account_id, confirmed: !account_id.nil?,
                    addresses: [addr]
                  )
                else
                  if !building.account_id.nil? && building.account_id != account_id
                    errors.push "Building on line #{bc['line']} (title '#{bldg[0]}') already exists and belongs to the wrong account! Aborting import..."
                    raise ActiveRecord::Rollback
                  end
                  building.update!(account_id: account_id, confirmed: true, enabled: true)
                end
                bb['units'].each do |u|
                  puts "[com ##{bc['line']}:#{com[0]}][bldg ##{bb['line']}:#{bldg[0]}] Get-or-creating unit #{u['line']}: #{u['title']}..."
                  found = building.units.find { |un| un.title == u['title'] }
                  if found.nil?
                    ::Insurable.create!(
                      insurable_id: building.id,
                      title: u['title'], insurable_type_id: 4, enabled: true, category: 'property',
                      account_id: account_id, confirmed: !account_id.nil?
                    )
                  else
                    if !found.account_id.nil? && found.account_id != account_id
                      errors.push "Unit on line #{u['line']} (title '#{u['title']}') already exists and belongs to the wrong account! Aborting import..."
                      raise ActiveRecord::Rollback
                    end
                    found.update!(account_id: account_id, confirmed: true, enabled: true)
                  end
                end
              end

            end
          end
        end
        import_success = true
        ### catch rollback if needed
      end

      if !import_success
        puts "Import failed. Errors:"
        InsurableUploadJobMailer.send_report(status: false, message: "<li>#{errors.join('</li><li>')}</li>", to: email).deliver
        errors.each { |x| puts "  #{x}" }
      else

        puts "Import succeeded. Queueing QBE calls."
        puts "Created community ids:"
        puts "  #{by_account.values.map { |ba| ba['by_community'].values.map { |bc| bc['in_system'].id } }.flatten}"
        InsurableUploadJobMailer.send_report(status: true, message: nil, to: email).deliver

        by_account.each do |account_id, ba|
          ba['by_community'].values.each do |bc|
            bc['in_system'].qbe_mark_preferred(strict: false, apply_defaults: true)
          end
        end
        puts "QBE calls queued."

      end
    end
  end
end
