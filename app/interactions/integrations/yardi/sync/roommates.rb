module Integrations
  module Yardi
    module Sync
      class Roommates < ActiveInteraction::Base # MOOSE WARNING: we don't have logic for tenant additions/removals, only full lease additions/removals
        object :integration
        string :property_id
        
        # returns hash of tcode changes
        def execute
          # prepare
          moveout_cutoff = ((Date.parse(integration.get_nested('sync', 'syncable_communities', property_id, 'last_sync_f')) - 1.day) rescue nil)
          to_return = {
            last_sync_f: moveout_cutoff&.to_s,
            errors: [],
            changes: {}
          }
          last_sync_f = Time.current.to_date.to_s # we'll set to_return[:last_sync_f] to this before returning, but it's convenient to wait so we can easily return without it if errors arise
          update_last_sync_f = true
          # perform
          result = Integrations::Yardi::ResidentData::GetRoommatePromotions.run!(integration: integration, property: property_id, move_out_from: moveout_cutoff)
          unless result[:success]
            to_return[:errors].push("Yardi call error (event ##{result[:event].id})")
            return(to_return)
          end
          if result[:request].body&.include?("No roommate promotions found")
            to_return[:last_sync_f] = last_sync_f
            return(to_return)
          end
          promotions = result[:parsed_response]&.dig("Envelope", "Body", "GetRoommatePromotionsResponse", "GetRoommatePromotionsResult", "PromotedRoommates", "Property", "RoommatePromotion")
          if promotions.nil?
            to_return[:errors].push("Unexpectedly nil promotion list (event ##{result[:event].id})")
            return(to_return)
          end
          promotions = [promotions] unless promotions.class == ::Array
          # process
          promotions.each.with_index do |promotion, promotion_index|
            # promotions look like this:
            #   {"PriorTenant"=>{"Code"=>"t0067609", "Name"=>"Sophia Wilson", "Status"=>"Past"},
            #    "NewTenant"=>{"Code"=>"t0081916", "Name"=>"David Wilson", "OldRoomateCode"=>"r0044076", "Status"=>"Current"},
            #    "MoveOutDate"=>"2022-06-08",
            #    "UnitCode"=>"207"}
            old_king_code = promotion["PriorTenant"]&.[]("Code") # was a merry old soud
            tcode_headstone = "was_#{Time.current.to_date.to_s}_#{old_king_code}"
            old_roommate_code = promotion["NewTenant"]&.[]("OldRoomateCode") || promotion["NewTenant"]&.[]("OldRoommateCode") # just in case yardi ever fixes their stupid spelling inconsistency...
            new_roommate_code = promotion["NewTenant"]&.[]("Code")
            # MOOSE WARNING: error handling for if yardi doesn't give us enough fields?? for now we will just skip it
            if old_king_code.nil? || old_roommate_code.nil? || new_roommate_code.nil?
              IntegrationProfile.create(
                integration: integration,
                profileable: integration,
                external_context: "log_roommate_promotion_broken",
                external_id: "#{property_id}__#{last_sync_f}__#{promotion_index}",
                configuration: { property_id: property_id, sync_time: last_sync_f, yardi_data: promotion }
              )
              next
            end
            # make sure we haven't already handled this one
            if integration.integration_profiles.where(external_context: "log_roommate_promotion", external_id: "#{new_roommate_code}__#{old_roommate_code}__#{old_king_code}").count > 0
              next
            end
            # check more deeply to see if we haven't handled this one (not logically necessary, but the legacy system attempted to DEDUCE tcode swaps and did not log them with IPs, so to maintain backwards compatibility we have to consider the possibility of unlogged swaps;
            # this code can be removed after it has run for a bit)
            if integration.integration_profiles.where(
            # handle stuff
            ActiveRecord::Base.transaction do
              # mark stuff handled
              loggo = IntegrationProfile.create(
                integration: integration,
                profileable: integration,
                external_context: "log_roommate_promotion",
                external_id: "#{new_roommate_code}__#{old_roommate_code}__#{old_king_code}",
                configuration: { property_id: property_id, yardi_data: promotion }
              )
              unless loggo.id
                to_return[:errors].push("Aborted roommate promotion due to failed IP save: #{loggo.errors.to_h}")
                update_last_sync_f = false # weird error, make sure we retry these by not updating the last sync date
              end
              # change the user-referring tcode folk NOTE: order matters! the new roommate tcode can be the same as the prior tenant tcode -____-"
              integration.integration_profiles.where(profileable_type: Integration::YARDI_TCODE_CHANGERS, external_id: old_king_code)
                                              .update_all(external_id: tcode_headstone)
              integration.integration_profiles.where(profileable_type: Integration::YARDI_TCODE_CHANGERS, external_id: old_roommate_code)
                                              .update_all(external_id: new_roommate_code)
              # change the lease and its lease user contexts
              integration.integration_profiles.where(external_context: 'lease', external_id: old_king_code)
                                              .update_all(external_id: new_roommate_code)
              integration.integration_profiles.where(external_context: "lease_user_for_lease_#{old_king_code}")
                                              .update_all(external_context: "lease_user_for_lease_#{new_roommate_code}")
              # update the prior LeaseUser
              prior_lease_user_ip = integration.integration_profiles.where(
                external_context: "lease_user_for_lease_#{new_roommate_code}",
                external_id: "was_#{Time.current.to_date.to_s}_#{old_king_code}"
              ).take
              to_update = {
                moved_out_at: (Date.parse(promotion["MoveOutDate"]) rescue nil),
                primary: false
              }.compact
              prior_lease_user_ip&.profileable&.update(to_update) unless to_update.blank?
              to_update = prior_lease_user_ip.configuration
              to_update['tcode_changes'] ||= {}
              to_update['tcode_changes'][last_sync_f] = {
                old_code: promotion["PriorTenant"]["Code"],
                new_code: tcode_headstone,
                move_out_date: promotion["MoveOutDate"],
                reason: 'promotion',
                details: "IntegrationProfile##{loggo.id}"
              }
              prior_lease_user_ip.update(configuration: to_update)
              # update the new LeaseUser
              new_lease_user_ip = integration.integration_profiles.where(
                external_context: "lease_user_for_lease_#{new_roommate_code}",
                external_id: new_roommate_code
              ).take
              unless new_lease_user_ip.nil? # just in case yardi gives us some garbage where we've never heard of this roommate before; we don't import here, since the Lease sync will do it
                to_update = new_lease_user_ip.configuration
                to_update['tcode_changes'] ||= {}
                to_update['tcode_changes'][last_sync_f] = {
                  old_code: old_roommate_code,
                  new_code: new_roommate_code,
                  move_out_date: nil,
                  reason: 'promotion',
                  details: "IntegrationProfile##{loggo.id}"
                }
                new_lease_user_ip.update(configuration: to_update)
                new_lease_user_ip.profileable&.update(moved_out_at: nil, primary: true)
              end
              # save a record of our troubles
              to_return[:changes][new_roommate_code] = tcode_headstone
            end # end transaction
          end # end promotions loop
          # tell our papa what we've done
          to_return[:last_sync_f] = (update_last_sync_f ? last_sync_f : moveout_cutoff&.to_s)
          return(to_return)
        end
        
        
        
        
      end
    end
  end
end
