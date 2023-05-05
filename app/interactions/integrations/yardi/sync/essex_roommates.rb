module Integrations
  module Yardi
    module Sync
      class EssexRoommates < ActiveInteraction::Base # MOOSE WARNING: we don't have logic for tenant additions/removals, only full lease additions/removals
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
          result = Integrations::Yardi::ResidentData::GetRoommatePromotions.run!(integration: integration, property_id: property_id, move_out_from: moveout_cutoff)
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
            # MOOSE WARNING: error handling for if yardi doesn't give us enough fields?? for now we will just log it and skip it
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
            if integration.integration_profiles.where(external_context: "log_roommate_promotion", external_id: "#{new_roommate_code}__#{old_roommate_code}__#{old_king_code}")
                          .or(integration.integration_profiles.where(external_context: ["log_roommate_promotion_broken", "log_roommate_promotion_unlogged"], external_id: "#{property_id}__#{last_sync_f}__#{promotion_index}"))
                          .count > 0
              next
            end
            # mark handled if the folk haven't even been imported yet (or if both are changed, which amounts to the same thing)
            if integration.integration_profiles.where(external_context: "resident", external_id: [old_roommate_code, old_king_code]).count == 0
              IntegrationProfile.create(
                integration: integration,
                profileable: integration,
                external_context: "log_roommate_promotion",
                external_id: "#{new_roommate_code}__#{old_roommate_code}__#{old_king_code}",
                configuration: { property_id: property_id, special_note: "promotion encountered before import", yardi_data: promotion }
              )
              next
            end
            # deal with situations where deduction/import has already brought in a lease with an altered tcode as a new lease
            if new_roommate_code != old_king_code
              eater_ip = integration.integration_profiles.where(external_context: "lease", external_id: new_roommate_code).take
              eaten_ip = integration.integration_profiles.where(external_context: "lease", external_id: old_king_code).take
              if !eater_ip.nil? && !eaten_ip.nil?
                eater = eater_ip.profileable
                eaten = eaten_ip.profileable
                if eater == eaten
                  # should be impossible, but just in case... MOOSE WARNING: add logic here?
                elsif eater.nil?
                  eater_ip.delete
                elsif eaten.nil?
                  eaten_ip.delete
                else
                  local_failure = false
                  ActiveRecord::Base.transaction(requires_new: true) do
                    eater_lus = eater.lease_users.to_a
                    eaten_lus = eaten.lease_users.to_a
                    # just slaughter the one to be eaten, if it can be slaughtered
                    if false && eaten_lus.all?{|lu| lu.user.sign_in_count == 0 && lu.user.policy_users.blank? } # MOOSE WARNING: this condition better be right! It can result in data destruction!!!
                      eaten_lus.each do |lu|
                        lu.user.profile.delete
                        lu.user.integration_profiles.delete_all
                        lu.user.address&.delete
                        lu.user.account_users.delete_all
                        lu.user.lease_users.each{|luu| luu.integration_profiles.delete_all; luu.delete }
                      end
                      eaten.integration_profiles.delete_all
                      eaten.delete
                      IntegrationProfile.create(
                        integration: integration,
                        profileable: integration,
                        external_context: "log_roommate_promotion_unlogged",
                        external_id: "#{property_id}__#{last_sync_f}__#{promotion_index}",
                        configuration: { property_id: property_id, sync_time: last_sync_f, yardi_data: promotion, action: "old_lease_killed" }
                      )
                      next
                    end
                    # merge the two;
                    # eaten lus can just be moved to the eater, since the lease sync will sort out tcode issues and perform necessary mergers;
                    # the only imperatives are for us is to handle the promotion ones & change all the lease_ids and external_contexts
                    eater_luips = integration.integration_profiles.where(profileable: eater_lus).to_a
                    eaten_luips = integration.integration_profiles.where(profileable: eaten_lus).to_a
                    # fix old codes
                    weirdos = (eater_luips + eaten_luips).group_by do |luip|
                      next :old_roommate_code if luip.external_id == old_roommate_code
                      next :old_king_code if luip.external_id == old_king_code
                      next nil
                    end
                    weirdos.delete(nil)
                    weirdos[:old_king_code]&.each do |luip| # MOOSE WARNING: we really ought to do a bit more here... should encapsulate the logging actions made in the standard flow to call em here too
                      luip.update(external_id: "was_#{Time.current.to_date.to_s}_#{old_king_code}")
                      luip.profileable.user.integration_profiles.where(integration: integration, external_id: old_king_code).update_all(external_id: "was_#{Time.current.to_date.to_s}_#{old_king_code}")
                    end
                    weirdos[:old_roommate_code]&.each do |luip|
                      # mmm there could be trouble there
                      luip.profileable.user.integration_profiles.where(integration: integration, external_context: "resident", external_id: old_king_code).update_all(external_id: "was_#{Time.current.to_date.to_s}_#{old_king_code}")
                      unless luip.update(external_id: new_roommate_code)
                        if eaten_luips.include?(luip)
                          # will go through merger as new_roommate_code then be set to the correct context afterwards when they all are
                          luip.update(external_id: new_roommate_code, external_context: "temporary_#{luip.id}")
                        else
                          # find the eaten one and change it instead
                          caribou = eaten_luips.find{|nluip| nluip.external_id == new_roommate_code }
                          caribou&.update(external_context: "temporary_#{caribou&.id}")
                          # now retry
                          luip.update(external_id: new_roommate_code)
                        end
                      end
                    end
                    # handle repeated codes
                    eater_lus = eater.lease_users.reload.to_a
                    eaten_lus = eaten.lease_users.reload.to_a
                    eater_luips = integration.integration_profiles.where(profileable: eater_lus).to_a
                    eaten_luips = integration.integration_profiles.where(profileable: eaten_lus).to_a
                    repeats = eater_luips.map{|luip| luip.external_id } & eaten_luips.map{|luip| luip.external_id }
                    repeats.each do |code|
                      rluip = eater_luips.find{|luip| luip.external_id == code }
                      nluip = eaten_luips.find{|luip| luip.external_id == code }
                      rlu = rluip.profileable
                      nlu = nluip.profileable
                      # do something simple in special situations
                      if rlu.nil? || nlu.nil?
                        rluip.delete if rlu.nil?
                        nluip.delete if nlu.nil?
                        next
                      elsif rlu.id == nlu.id
                        nluip.delete
                        next
                      elsif rlu.user_id == nlu.user_id
                        nlu.delete
                        nluip.delete
                        next
                      end
                      # merge the users
                      ru = rlu.user
                      nu = nlu.user
                      saved = [ru, nu].max_by{|x| [x.sign_in_count, -x.created_at.to_i] }
                      doomed = [ru, nu].find{|x| x.id != saved.id }
                      result = saved.absorb!(doomed)
                      unless result.nil?
                        to_return[:errors].push("Failed to merge User ##{doomed.id} into User ##{saved.id}! #{result.class.name}: #{(result.message rescue "<no message>")}")
                        IntegrationProfile.create(
                          integration: integration,
                          profileable: integration,
                          external_context: "log_roommate_promotion_broken",
                          external_id: "#{property_id}__#{last_sync_f}__#{promotion_index}",
                          configuration: { property_id: property_id, sync_time: last_sync_f, yardi_data: promotion, error: to_return[:errors].last }
                        )
                        local_failure = true
                        raise ActiveRecord::Rollback
                      end
                      (saved.id == ru.id ? [nlu, nluip] : [rlu, rluip]).each{|x| x.delete } # we don't need two copies of the same lease user and lease user IP in the db
                    end
                    # refresh eaten
                    eater_lus = eater.lease_users.reload.to_a
                    eaten_lus = eaten.lease_users.reload.to_a
                    eaten_luips = integration.integration_profiles.where(profileable: eaten_lus).reload
                    eaten_luips.each{|luip| luip.profileable.update!(lease: eater) }
                    eaten_luips.update_all(external_context: "lease_user_for_lease_#{new_roommate_code}")
                    eaten.integration_profiles.delete_all
                    eaten.delete                    
                    IntegrationProfile.create(
                      integration: integration,
                      profileable: integration,
                      external_context: "log_roommate_promotion_unlogged",
                      external_id: "#{property_id}__#{last_sync_f}__#{promotion_index}",
                      configuration: { property_id: property_id, sync_time: last_sync_f, yardi_data: promotion, special: "singularized_lease" }
                    )
                  end # end transaction
                  next
                end
              end
            end
            # check more deeply to see if we haven't handled this one (not logically necessary, but the legacy system attempted to DEDUCE tcode swaps and did not log them with IPs, so to maintain backwards compatibility we have to consider the possibility of unlogged swaps;
            # this code can be removed after it has run for a bit)
            if(
              integration.integration_profiles.where(external_context: "resident", external_id: old_roommate_code).blank? &&
              (integration.integration_profiles.where(external_context: "resident", external_id: new_roommate_code).count > 0) &&
              (old_king_code == new_roommate_code || integration.integration_profiles.where(external_context: "resident", external_id: old_king_code).blank?)
            )
              skip_it = (old_king_code != new_roommate_code)
              unless skip_it
                prof = integration.integration_profiles.where(external_context: "resident", external_id: new_roommate_code).take.profileable.profile
                skip_it = (
                  promotion['NewTenant']['Name'].downcase.strip.start_with?( (prof.first_name == "Unknown" && !promotion['NewTenant']['Name'].strip.start_with?('Unknown') ? "" : prof.first_name).downcase.strip ) &&
                  promotion['NewTenant']['Name'].downcase.strip.end_with?( (prof.last_name == "Unknown" && !promotion['NewTenant']['Name'].strip.end_with?('Unknown') ? "" : prof.last_name).downcase.strip )
                )
              end
              if skip_it
                IntegrationProfile.create(
                  integration: integration,
                  profileable: integration,
                  external_context: "log_roommate_promotion_unlogged",
                  external_id: "#{property_id}__#{last_sync_f}__#{promotion_index}",
                  configuration: { property_id: property_id, sync_time: last_sync_f, yardi_data: promotion }
                )
                next
              end
            end
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
              # first do a reverse fix if necessary
              if !integration.integration_profiles.where(external_context: "lease", external_id: new_roommate_code).blank?
                lu = integration.integration_profiles.where(external_context: "lease_user_for_lease_#{new_roommate_code}", external_id: new_roommate_code).take&.profileable
                prof = lu&.user&.profile
                if !lu.nil? && (
                  promotion['PriorTenant']['Name'].downcase.strip.start_with?( (prof.first_name == "Unknown" && !promotion['PriorTenant']['Name'].strip.start_with?('Unknown') ? "" : prof.first_name).downcase.strip ) &&
                  promotion['PriorTenant']['Name'].downcase.strip.end_with?( (prof.last_name == "Unknown" && !promotion['PriorTenant']['Name'].strip.end_with?('Unknown') ? "" : prof.last_name).downcase.strip )
                )
                  integration.integration_profiles.where(external_id: new_roommate_code).update_all(external_id: old_king_code)
                  integration.integration_profiles.where(external_context: "lease_user_for_lease_#{new_roommate_code}").update_all(external_context: "lease_user_for_lease_#{old_king_code}")
                end
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
                external_id: tcode_headstone
              ).take
              unless prior_lease_user_ip.nil?
                to_update = {
                  moved_out_at: (Date.parse(promotion["MoveOutDate"]) rescue nil),
                  primary: false
                }.compact
                prior_lease_user_ip.profileable&.update(to_update) unless to_update.blank?
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
              end
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
