module Integrations
  module Yardi
    module Sync
      class RoommatesEssex < ActiveInteraction::Base # MOOSE WARNING: we don't have logic for tenant additions/removals, only full lease additions/removals
        object :integration
        string :property_id
        array :csv_data
        
        CSV_FORMAT = {
          property_id: 0,
          primary_code: 5,
          new_primary_first_name: 6,
          new_primary_last_name: 7,
          rooommate_code: 8,
          old_primary_first_name: 9,
          old_primary_last_name: 10,
          roommate_move_out: 11
        }
        
        # returns hash of tcode changes
        def execute
          last_sync_f = Date.parse(integration.get_nested('sync', 'syncable_communities', property_id, 'last_sync_f'))
          to_return = {
            last_sync_f: last_sync_f,
            errors: [],
            changes: {}
          }
          info = csv_data.select.with_index{|row,ind| ind != 0 && row[CSV_FORMAT[:property_id]]&.strip&.downcase == property_id.strip.downcase }
          info.each.with_index do |row, promotion_index|
            primary_code = row[CSV_FORMAT[:primary_code]]&.strip
            roommate_code = row[CSV_FORMAT[:roommate_code]]&.strip
            move_out = row[CSV_FORMAT[:roommate_move_out]]&.strip
            move_out = (move_out.blank? ? nil : Date.strptime("#{move_out}", "%m/%d/%Y") rescue :broken)
            if move_out == :broken
              IntegrationProfile.create(
                integration: integration,
                profileable: integration,
                external_context: "log_roommate_promotion_broken",
                external_id: "#{property_id}__#{last_sync_f}__#{primary_code}",
                configuration: { property_id: property_id, sync_time: last_sync_f, yardi_data: row, error: "Unable to parse move-out date '#{row[CSV_FORMAT[:roommate_move_out]]&.strip}'" }
              )
              next
            end
            orig_primary_uip = integration.integration_profiles.where(external_context: "resident", external_id: primary_code).take
            orig_roommate_uip = integration.integration_profiles.where(external_context: "resident", external_id: roommate_code).take
            orig_primary_luip = integration.integration_profiles.where(external_context: "lease_user_for_lease_#{primary_code}", external_id: primary_code).take
            orig_roommate_luip = integration.integration_profiles.where(external_context: "lease_user_for_lease_#{primary_code}", external_id: roommate_code).take
            # make sure we haven't already handled this one
            if integration.integration_profiles.where(external_context: "log_roommate_promotion", external_id: "#{primary_code}__#{roommate_code}__#{primary_code}")
                          .or(integration.integration_profiles.where(external_context: ["log_roommate_promotion_broken", "log_roommate_promotion_unlogged"], external_id: "#{property_id}__#{last_sync_f}__#{primary_code}"))
                          .count > 0
              next
            end
            # do it bro, do it
            begin
              ActiveRecord::Base.transaction(requires_new: true) do
                orig_primary_uip&.update!(external_id: "changing_#{primary_code}")
                orig_primary_luip&.update!(external_id: "changing_#{primary_code}")
                orig_roommate_uip&.update!(external_id: primary_code)
                orig_roommate_luip&.update!(external_id: primary_code)
                orig_primary_uip&.update!(external_id: roommate_code)
                orig_primary_luip&.update!(external_id: roommate_code)
                IntegrationProfile.create!(
                  integration: integration,
                  profileable: integration,
                  external_context: "log_roommate_promotion",
                  external_id: "#{primary_code}__#{roommate_code}__#{primary_code}",
                  configuration: { property_id: property_id, special_note: "essex", yardi_data: row }
                )
              end
            rescue StandardError => e
              IntegrationProfile.create(
                integration: integration,
                profileable: integration,
                external_context: "log_roommate_promotion_broken",
                external_id: "#{property_id}__#{last_sync_f}__#{primary_code}",
                configuration: { property_id: property_id, sync_time: last_sync_f, yardi_data: row, error: "#{e.class.name}: #{e.message}" }
              )
            end
          end
          # all done
          to_return[:last_sync_f] = Time.current.to_date.to_s
          return(to_return)
        end  
          
        
        
        
      end
    end
  end
end
