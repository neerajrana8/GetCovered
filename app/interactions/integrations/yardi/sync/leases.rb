
# MOOSE WARNING: Might want to periodically sync PolicyUser external ids to LeaseUser ones


module Integrations
  module Yardi
    module Sync
      class Leases < ActiveInteraction::Base # MOOSE WARNING: we don't have logic for tenant additions/removals, only full lease additions/removals
        object :integration
        object :unit, class: Insurable
        array :resident_data
        boolean :update_old, default: false # if you pass true, will run update on past leases that are already in the system; if false, it will ignore them
        boolean :cleanse_lease_users, default: false
        
        RESIDENT_STATUSES = {
          'past' => ['Past', 'Canceled', 'Cancelled'],
          'present' => ['Current'],
          'nonfuture' => ['Notice', 'Eviction'],
          'future' => ['Future'],
          'potential' => ['Applicant', 'Wait List'],
          'null' => ['Denied']
        }
        ALLOW_USER_CHANGE = true # true to allow previously imported users that aren't primary leaseholders to change to emailless users if their email appears used by a distinct primary user
        ATTEMPT_TO_USE_EMAIL = false # true to attempt to make email-bearing users with email UIDs, 'primary' to try only for primary leaseholders, false to never try (and if ALLOW_USER_CHANGE is true, users who have logged in & primary leaseholders will have priority in doing so)
        
        def tenant_user_match(ten, user)
          firster = (ten["FirstName"].blank? ? "Unknown" : ten["FirstName"]).strip.downcase
          laster = (ten["LastName"].blank? ? "Unknown" : ten["LastName"]).strip.downcase
          return (user.profile.contact_email || "") == (ten["Email"] || "") && firster == user.profile.first_name.strip.downcase && laster == user.profile.last_name.strip.downcase
        end
        
        def find_or_create_user(tenant, ten)
          # grab the fellow directly if they have already been imported
          primary = (tenant["Id"] == ten["Id"])
          user = IntegrationProfile.where(integration: integration, external_context: "resident", external_id: ten["Id"]).take&.profileable
          return user unless user.nil?
          # figure out if the email is used & if a matching user already exists
          firster = (ten["FirstName"].blank? ? "Unknown" : ten["FirstName"]).strip
          laster = (ten["LastName"].blank? ? "Unknown" : ten["LastName"]).strip
          email_bearer = ten["email"].blank? ? nil : User.where(email: ten["Email"])  # MOOSE WARNING: the query on the following line for users is INCOMPREHENSIBLY HORRIFYING. CHANGE IT, it is so inefficient, omfg...
          candidates = ten["Email"].blank? || (firster == "Unknown" || laster == "Unknown") ? [] : ([email_bearer] + User.references(:profiles).includes(:profile).where.not(email: ten["Email"]).where(profiles: { contact_email: ten["Email"] }).to_a).compact
          candidates.select!{|u| u.profile.first_name&.downcase&.strip == firster.downcase && u.profile.last_name&.downcase&.strip == laster.downcase }
          user = candidates.find{|c| c.integration_profiles.any?{|ip| ip.integration_id == integration.id } } || candidates.first # there should be at most 1 candidate; if not, we could merge them, but instead lets just take the best one and continue
          # create the user if necessary & create the UIP
          ActiveRecord::Base.transaction(requires_new: true) do
            if user.nil?
              # there is no matching user
              if !ten["Email"].blank? && (ATTEMPT_TO_USE_EMAIL == true || (primary && ATTEMPT_TO_USE_EMAIL == 'primary'))
                # we want to use an email
                if !email_bearer.nil?
                  # try to remove the email from the email-bearer
                  unmodifiable = ( (!ALLOW_USER_CHANGE) || (!primary) || (email_bearer.sign_in_count > 0) || (email_bearer.lease_users.where(primary: true).count > 0) || (email_bearer.integration_profiles.where(provider: 'yardi').count == 0) )
                  if unmodifiable == false
                    abandon_attempt = false
                    abandon_attempt = true unless email_bearer.profile.update(contact_email: email_bearer.email)
                    unless abandon_attempt
                      email_bearer.provider = 'altuid'
                      email_bearer.altuid = Time.current.to_i.to_s + rand.to_s
                      email_bearer.uid = email_bearer.altuid
                      abandon_attempt = true unless email_bearer.save
                      unless abandon_attempt
                        email_bearer = nil
                      end
                    end
                  end
                end
                # create our user, using the email if we lacked an email_bearer or were able to remove its email
                user = ::User.create_with_random_password(email: email_bearer.nil? ? ten["Email"] : nil, profile_attributes: {
                  first_name: firster,
                  last_name: laster,
                  middle_name: ten["MiddleName"],
                  contact_phone: ten["Phone"]&.select{|x| x["PhoneDescription"] == "cell" || x["PhoneDescription"] == "home" }&.sort_by{|x| { "cell" => 0, "home" => 1 }[x["PhoneDescription"]] || 999 }&.first&.[]("PhoneNumber"),
                  contact_email: ten["Email"]
                }.compact)
              else
                # we don't even want to use an email
                user = ::User.create_with_random_password(email: nil, profile_attributes: {
                  first_name: firster,
                  last_name: laster,
                  middle_name: ten["MiddleName"],
                  contact_phone: ten["Phone"]&.select{|x| x["PhoneDescription"] == "cell" || x["PhoneDescription"] == "home" }&.sort_by{|x| { "cell" => 0, "home" => 1 }[x["PhoneDescription"]] || 999 }&.first&.[]("PhoneNumber")
                }.merge(ten["Email"].blank? ? {} : { contact_email: ten["Email"] }).compact)
              end
            end
            # freak out on failure
            if user&.id.nil?
              user_errors[tenant["Id"]] ||= {}
              user_errors[tenant["Id"]][ten["Id"]] = "Failed to create user #{ten["FirstName"]} #{ten["LastName"]}: #{user.errors.to_h}"
              user = nil
              raise ActiveRecord::Rollback
            end
            # make sure we construct an IP (which definitely doesn't exist since we early-exited this function if it did)
            ip = IntegrationProfile.create(
              integration: integration,
              profileable: user,
              external_context: "resident",
              external_id: ten["Id"],
              configuration: {
                'synced_at' => Time.current.to_s,
                'post_fix_em' => 'IMPORT',
                'post_revamp' => true
              }
            )
            if ip.id.nil?
              user_errors[tenant["Id"]] ||= {}
              user_errors[tenant["Id"]][ten["Id"]] = "Failed to create IntegrationProfile for user #{ten["FirstName"]} #{ten["LastName"]}: #{ip.errors.to_h}"
              user = nil
              raise ActiveRecord::Rollback
            end
          end # end transaction
          return user
        end
        
        def fix_ridiculous_swaps(lease, tenant, da_tenants)
          # this has been superseded by roommate sync, but I am leaving the code here for now in case it's needed
          return
          # look for residents whose codes have swapped
          from_system = lease.lease_users.map{|lu| [lu.integration_profiles.take&.external_id, { lease_user: lu, first_name: lu.user.profile.first_name, last_name: lu.user.profile.last_name, middle_name: lu.user.profile.middle_name }] }.to_h
          from_yardi = da_tenants.map do |ten|
            firster = (ten["FirstName"].blank? ? "Unknown" : ten["FirstName"]).strip
            laster = (ten["LastName"].blank? ? "Unknown" : ten["LastName"]).strip
            middler = ten["MiddleName"]
            [ten["Id"], { first_name: ten["FirstName"], last_name: ten["LastName"], middle_name: middler }]
          end.to_h
          # build name-based mapping
          changed = []
          mapping = from_system.map do |eid, system_data|
            next [eid, eid] if from_yardi[eid]&.[](:first_name) == system_data[:first_name] && from_yardi[eid]&.[](:last_name) == system_data[:last_name]
            next [eid,
              from_yardi.select{|yeid, ydata| ydata[:first_name] == system_data[:first_name] && ydata[:last_name] == system_data[:last_name] }.keys&.first
            ]
          end.to_h
          # find flipsy flopsies and flop their ids about
          kings_of_the_sea = []
          mapping.each{|seid, yeid| kings_of_the_sea.push({ seid: seid, yeid: yeid }) if yeid != seid && mapping[yeid] == seid && !kings_of_the_sea.any?{|flipper| flipper[:seid] == yeid && flipper[:yeid] == seid } }
          kings_of_the_sea.each do |flipper|
            next if !from_system.has_key?(flipper[:seid]) || !from_system.has_key?(flipper[:yeid])
            Integrations::Yardi::SwapResidentIds.run!(integration: integration, id1: flipper[:seid], id2: flipper[:yeid])
          end
        end
        

        # find folk lacking something
        def fix_missing(lease, tenant, da_tenants)
          # get ready boyo
          errors = []

          # grab folk with lacks
          uips = integration.integration_profiles.where(external_context: "resident", external_id: da_tenants.map{|dt| dt["Id"] }).to_a
          luips = integration.integration_profiles.where(profileable: lease.lease_users).to_a
          tenanted_luips = luips.select{|luip| da_tenants.any?{|t| t["Id"] == luip.external_id } }
          free_lus = lease.lease_users.select{|lu| !tenanted_luips.any?{|luip| luip.profileable_id == lu.id } }.to_a
          ejected_users = []
          lacks_both = da_tenants.map{|dt| dt["Id"] }.select{|i| !uips.any?{|uip| uip.external_id == i } && !luips.any?{|luip| luip.external_id == i } }
          lacks_uip = (da_tenants.map{|dt| dt["Id"] } - lacks_both).select{|i| !uips.any?{|uip| uip.external_id == i } }
          lacks_luip = (da_tenants.map{|dt| dt["Id"] } - lacks_both).select{|i| !luips.any?{|luip| luip.external_id == i } }
          lacks_match = (da_tenants.map{|dt| dt["Id"] } - (lacks_uip | lacks_luip | lacks_both)).select{|i| uips.find{|uip| uip.external_id == i }.profileable_id != luips.find{|luip| luip.external_id == i }.profileable.user_id }
          # grab full tenant hashes instead
          lacks_both = da_tenants.select{|dt| lacks_both.include?(dt["Id"]) }
          lacks_uip = da_tenants.select{|dt| lacks_uip.include?(dt["Id"]) }
          lacks_luip = da_tenants.select{|dt| lacks_luip.include?(dt["Id"]) }
          lacks_match = da_tenants.select{|dt| lacks_match.include?(dt["Id"]) }
          # set up other useful things
          lacks_both_no_more = []
          lacks_uip_no_more = []
          lacks_luip_no_more = []
          lacks_match_no_more = []

          # handle match-lackers

          lacks_match.each do |ten|
            luip = luips.find{|luip| luip.external_id == ten["Id"] }
            uip = uips.find{|uip| uip.external_id == ten["Id"] }
            succeeded = false
            if tenant_user_match(ten, luip.profileable.user)
              if tenant_user_match(ten, uip.profileable)
                # both user records are the right user; time to merge 'em
                saved = [uip.profileable, luip.profileable.user].max_by{|x| [x.sign_in_count, -x.created_at.to_i] }
                doomed = [uip.profileable, luip.profileable.user].find{|x| x.id != saved.id }
                doomed_id = doomed.id
                result = saved.absorb!(doomed)
                if result.nil?
                  succeeded = true
                else
                  errors.push("Failed to merge User ##{doomed.id} into User ##{saved.id} (tenant #{ten["Id"]})! #{result.class.name}: #{(result.message rescue "<no message>")}")
                  next
                end
              else
                # only the luip matches ten
                # WARNING: should we set the user to "was_whatever" to log that this happened?
                ejected_users.push(uip.profileable)
                if uip.update(profileable_id: luip.profileable.user_id)
                  succeeded = true 
                else
                  ejected_users.pop
                  errors.push("Failed to move UIP##{uip.id} from User##{uip.profileable_id} to User##{luip.profileable.uiser_id} (tenant #{ten["Id"]})! #{uip.errors.to_h}")
                  next
                end
              end
            elsif tenant_user_match(ten, uip.profileable)
              # only the uip matches ten
              ejected_users.push(luip.profileable.user)
              if luip.profileable.update(user_id: uip.profileable_id)
                succeeded = true
              else
                ejected_users.pop
                errors.push("Failed to move LUIP##{luip.id}'s LeaseUser##{luip.profileable_id} from User##{luip.profileable.user_id} to User##{uip.profileable_id} (tenant #{ten["Id"]})! #{luip.errors.to_h}")
              end
            else
              # neither of the records match ten; switch them both to different tcodes
              begin
                ActiveRecord::Base.transaction(requires_new: true) do
                  new_external_id = "had_lease_user_#{Time.current.to_date.to_s}_#{luip.external_id}"
                  luip.configuration ||= {}
                  luip.configuration['tcode_changes'] ||= {}
                  luip.configuration['tcode_changes'][Time.current.to_date] = {
                    old_code: luip.external_id,
                    new_code: new_external_id,
                    reason: 'lacked_match',
                    detals: "User##{uip.profileable_id}"
                  }
                  luip.external_id = new_external_id
                  luip.save!
                  uip.update!(external_id: "was_#{Time.current.to_date.to_s}_#{luip.external_id}")
                  # mark successful
                  tenanted_luips.delete(luip)
                  free_lus.push(luip.profileable)
                  uips.delete(uip)
                  lacks_both.push(ten)
                  succeeded = true
                end
              rescue StandardError => e
                errors.push("Failed to change tcodes of UIP##{uip.id} and LUIP##{luip.id}, which do not match the tenant (tenant #{ten["Id"]})! #{e.class.name}: #{(e.message rescue "")}")
              end
            end
            # handle success
            if succeeded
              # mark successful
              lacks_match_no_more.push(ten)
              next
            end
          end

          # handle uip-lackers

          lacks_uip.each do |ten|
            luip = luips.find{|luip| luip.external_id == ten["Id"] }
            uip = integration.integration_profiles.create(
              profileable_type: "User",
              profileable_id: luip.profileable.user_id,
              external_context: "resident",
              external_id: ten["Id"],
              configuration: {
                'synced_at' => Time.current.to_s,
                'post_fix_em' => true,
                'post_revamp' => true
              }
            )
            if uip.id.nil?
              errors.push("Failed to create UIP for User##{luip.profileable.user_id} corresponding to LUIP##{luip.id} (tenant #{ten["Id"]})! #{uip.errors.to_h}")
            else
              uips.push(uip)
              lacks_uip_no_more.push(ten)
            end
          end

          # handle both-lackers

          lacks_both.each do |ten|
            # first make sure there's no exact name/email match
            candidate_lu = free_lus.find{|lu| tenant_user_match(ten, lu.user) }
            unless candidate_lu.nil?
              # we have someone who matches the name and email
              luip = integration.integration_profiles.create(
                external_context: "lease_user_for_lease_#{tenant["Id"]}",
                external_id: ten["Id"],
                profileable: candidate_lu,
                configuration: { 'synced_at' => Time.current.to_s, 'post_fix_em' => true, 'post_revamp' => true }
              )
              unless luip.id
                errors.push("Failed to create LUIP for LU##{candidate_lu.id} based on User match (tenant #{ten["Id"]})! #{luip.errors.to_h}")
                next
              end
              # mark successful
              luips.push(luip)
              tenanted_luips.push(luip)
              free_lus.select!{|fl| fl.id != luip.profileable_id }
              lacks_both_no_more.push(ten)
              next
            end
            # then fall back to creating something new
            local_failed = false
            user = nil
            luip = nil
            ActiveRecord::Base.transaction(requires_new: true) do
              user ||= find_or_create_user(tenant, ten) # this creates the UIP as well
              if user.nil?
                errors.push("Failed to find-or-create User for tenant (tenant #{ten["Id"]})!")
                local_failed = true
                raise ActiveRecord::Rollback
              end
              lu = lease.lease_users.create(
                user: user,
                primary: ten["Id"] == tenant["Id"],
                lessee: (ten["Id"] == tenant["Id"] || ten["Lessee"] == "Yes"),
                moved_in_at: (Date.parse(ten["MoveIn"]) rescue nil),
                moved_out_at: (Date.parse(ten["MoveOut"]) rescue nil)
              )
              if lu.id.nil?
                errors.push("Failed to create LeaseUser for (possibly about-to-be-rolled-back) User##{user.id} (tenant #{ten["Id"]})! #{lu.errors.to_h}")
                local_failed = true
                raise ActiveRecord::Rollback
              end
              luip = integration.integration_profiles.create(
                external_context: "lease_user_for_lease_#{tenant["Id"]}",
                external_id: ten["Id"],
                profileable: lu,
                configuration: { 'synced_at' => Time.current.to_s, 'post_fix_em' => true, 'post_revamp' => true }
              )
              if luip&.id.nil?
                errors.push("Failed to create LUIP for (possibly about-to-be-rolled-back) User##{user.id} (tenant #{ten["Id"]})! #{luip.errors.to_h}")
                local_failed = true
                raise ActiveRecord::Rollback
              end
            end
            unless local_failed
              # mark successful
              uips.push(user.integration_profiles.where(integration: integration, external_context: "resident", external_id: ten["Id"]).take)
              luips.push(luip)
              tenanted_luips.push(luip)
              free_lus.select!{|fl| fl.id != luip.profileable_id }
              lacks_both_no_more.push(ten)
              next
            end
          end

          # handle luip-lackers

          lacks_luip.each do |ten|
            uip = uips.find{|ip| ip.external_id == ten["Id"] }
            # first make sure there's no exact User match
            candidate_lu = lease.lease_users.find{|lu| lu.user_id == uip.profileable_id }
            unless candidate_lu.nil?
              # we have an exact match for the user we're looking for
              luip = integration.integration_profiles.create(
                external_context: "lease_user_for_lease_#{tenant["Id"]}",
                external_id: ten["Id"],
                profileable: candidate_lu,
                configuration: { 'synced_at' => Time.current.to_s, 'post_fix_em' => true, 'post_revamp' => true }
              )
              unless luip.id
                errors.push("Failed to create LUIP for LU##{candidate_lu.id} based on exact User id match (tenant #{ten["Id"]})! #{luip.errors.to_h}")
                next
              end
              # mark successful
              luips.push(luip)
              tenanted_luips.push(luip)
              free_lus.select!{|fl| fl.id != luip.profileable_id }
              lacks_luip_no_more.push(ten)
              next
            end
            # then make sure there's no exact name/email match
            candidate_lu = free_lus.find{|lu| tenant_user_match(ten, lu.user) }
            unless candidate_lu.nil?
              # we have someone who matches the name and email of the other guy
              saved = [candidate_lu.user, uip.profileable].max_by{|x| [x.sign_in_count, -x.created_at.to_i] }
              doomed = [candidate_lu.user, uip.profileable].find{|x| x.id != saved.id }
              doomed_id = doomed.id
              result = saved.absorb!(doomed)
              unless result.nil?
                errors.push("Failed to merge User##{doomed.id} into User##{saved.id} (tenant #{ten["Id"]})! #{result.class.name}: #{(result.message rescue "")}")
                next
              end
              # create luip
              luip = integration.integration_profiles.create(
                external_context: "lease_user_for_lease_#{tenant["Id"]}",
                external_id: ten["Id"],
                profileable: candidate_lu,
                configuration: { 'synced_at' => Time.current.to_s, 'post_fix_em' => true, 'post_revamp' => true }
              )
              unless luip.id
                errors.push("Failed to create LUIP for User##{saved.id} after merging in User##{doomed_id} (tenant #{ten["Id"]})! #{luip.errors.to_h}")
                next
              end
              # mark successful
              luips.push(luip)
              tenanted_luips.push(luip)
              free_lus.select!{|fl| fl.id != luip.profileable_id && fl.id != doomed_id }
              lacks_luip_no_more.push(ten)
              next
            end
            # then fall back to creating something new
            local_failed = false
            ActiveRecord::Base.transaction(requires_new: true) do
              lu = lease.lease_users.create(
                user: uip.profileable,
                primary: ten["Id"] == tenant["Id"],
                lessee: (ten["Id"] == tenant["Id"] || ten["Lessee"] == "Yes"),
                moved_in_at: (Date.parse(ten["MoveIn"]) rescue nil),
                moved_out_at: (Date.parse(ten["MoveOut"]) rescue nil)
              )
              if lu.id.nil?
                local_failed = true
                errors.push("Failed to create LeaseUser for User##{uip.profileable_id} (tenant #{ten["Id"]})! #{lu.errors.to_h}")
                raise ActiveRecord::Rollback
              end
              luip = integration.integration_profiles.create(
                external_context: "lease_user_for_lease_#{tenant["Id"]}",
                external_id: ten["Id"],
                profileable: lu,
                configuration: { 'synced_at' => Time.current.to_s, 'post_fix_em' => true, 'post_revamp' => true }
              )
              if luip.id.nil?
                local_failed = true
                errors.push("Failed to create LUIP for to-be-rolled-back LeaseUser for User##{uip.profileable_id} (tenant #{ten["Id"]})! #{luip.errors.to_h}")
                raise ActiveRecord::Rollback
              end
            end
            unless local_failed
              # mark successful
              luips.push(luip)
              tenanted_luips.push(luip)
              free_lus.select!{|fl| fl.id != luip.profileable_id }
              lacks_luip_no_more.push(ten)
              next
            end
          end
          
          # handle free_lus and ejected_users
          ejected_users.select!{|eu| !lease.lease_users.reload.any?{|lu| lu.user_id == eu.id } }
          ejected_users.uniq!
          (free_lus + ejected_users).each do |itm| # WARNING: logic changes free_lus/ejected_users inside
            user = (itm.class == ::LeaseUser ? itm.user : itm)
            lease_user = (itm.class == ::LeaseUser ? itm : nil)
            # look for matches
            tenanted_luips.each do |luip|
              ten = da_tenants.find{|dt| dt["Id"] == luip.external_id }
              next unless tenant_user_match(ten, user)
              # perform absorption
              saved = [user, luip.profileable.user].max_by{|x| [x.sign_in_count, -x.created_at.to_i] }
              doomed = [user, luip.profileable.user].find{|x| x.id != saved.id }
              result = saved.absorb!(doomed)
              # get rid of the old LU
              lease_user&.integration_profiles&.delete_all
              lease_user&.delete
              # log our magic
              free_lus.delete(lease_user) unless lease_user.nil?
              ejected_users.delete(user)
              break
            end
          end
          
          # delete lus for which there was no match, if the cleanse_lease_users flag is enabled
          if cleanse_lease_users
            free_lus.each do |dl|
              dl.integration_profiles.each{|ip| ip.delete }
              dl.delete
            end
          end
          
          # handle results
          lacks_both -= lacks_both_no_more
          lacks_uip -= lacks_uip_no_more
          lacks_luip -= lacks_luip_no_more
          lacks_match -= lacks_match_no_more
          
          # all done
          return({
            success: lacks_both.blank? && lacks_uip.blank? && lacks_luip.blank? && lacks_match.blank?,
            errors: errors
          })
        end # end fix_missing(lease, da_tenants)

        
        
        
        def execute
          # scream if integration is invalid
          return { lease_errors: { 'all' => "No yardi integration provided" } } unless integration
          return { lease_errors: { 'all' => "Invalid yardi integration provided" } } unless integration.provider == 'yardi'
          # set up outputs
          lease_errors = {}
          created_leases = {}
          found_leases = {}
          expired_leases = {}
          user_errors = {}
          created_users = {}
          found_users = {}
          update_errors = {}
          # group resident leases
          resident_datas = resident_data.group_by{|td| td["Status"] }
          future_tenants = (
            (RESIDENT_STATUSES['future'] || []).map{|s| resident_datas[s] || [] } +
            ((integration.id == 6 || integration.id == 14) ? (resident_datas['Applicant'] || []) : [])
          ).flatten
          present_tenants = (
            (RESIDENT_STATUSES['present'] || []).map{|s| resident_datas[s] || [] } +
            (RESIDENT_STATUSES['nonfuture'] || []).map{|s| (resident_datas[s] || []).select{|td| td['MoveOut'].blank? || (Date.parse(td['MoveOut']) rescue nil)&.>=(Time.current.to_date) } }
          ).flatten
          past_tenants = (
            (RESIDENT_STATUSES['past'] || []).map{|s| resident_datas[s] || [] } +
            ((integration.id == 6 || integration.id == 14) ? (resident_datas['Denied'] || []) : []) +
            (RESIDENT_STATUSES['nonfuture'] || []).map{|s| (resident_datas[s] || []).select{|td| !td['MoveOut'].blank? && (Date.parse(td['MoveOut']) rescue nil)&.<(Time.current.to_date) } }
          ).flatten
          # grab some variables we shall require in the execution of our noble purpose
          in_system = IntegrationProfile.where(integration: integration, external_context: 'lease', external_id: resident_data.map{|l| l['Id'] }).pluck(:external_id)
          relevant_tenants = present_tenants + future_tenants
          noncreatable_start = relevant_tenants.count
          relevant_tenants += resident_data.select{|x| !relevant_tenants.include?(x) && in_system.include?(x["Id"]) } if update_old
          created_by_email = {}
          user_ip_ids = IntegrationProfile.where(integration: integration, external_context: 'resident', profileable_type: "User").pluck(:external_id, :profileable_id).to_h
          # mark defunct those leases which the horrific architecture of Yardi's database requires to be removed from their system when they have been superseded
          # MOOSE WARNING: the 'defunct' boolean is a placeholder architectural solution just to get the feature working. ultimately we should be giving these leases a special status and doing something to their IPs...
          IntegrationProfile.where(integration: integration, external_context: 'lease', profileable: unit.leases.where(defunct: false)).where.not(external_id: in_system).each do |lip|
            lip.profileable.update(defunct: true, status: 'expired') 
          end
          # update leases to expired
          in_system_lips = IntegrationProfile.references(:leases).includes(:lease).where(integration: integration, external_context: 'lease', external_id: past_tenants.map{|l| l['Id'] }, profileable_type: "Lease", leases: { status: ['current', 'pending'] })
          in_system_lips.each do |ip|
            rec = past_tenants.find{|l| l['Id'] == ip.external_id }
            l = ip.lease
            found_leases[ip.external_id] = l
            if l.update({ insurable_id: unit.id, start_date: rec["LeaseFrom"].blank? ? nil : Date.parse(rec["LeaseFrom"]), end_date: rec["LeaseTo"].blank? ? Time.current.to_date : Date.parse(rec["LeaseTo"]), status: 'expired' }.compact)
              expired_leases[ip.external_id] = l
            else
              lease_errors[ip.external_id] = "Failed to mark lease (GC id #{l.id}) expired: #{l.errors.to_h}"
            end
          end
          in_system_lips = nil
          # create active new and future leases (and run updates)
          relevant_tenants.each.with_index do |tenant, tenant_index|
            da_tenants = [tenant] + (tenant["Roommate"].nil? ? [] : tenant["Roommate"].class == ::Array ? tenant["Roommate"] : [tenant["Roommate"]])
            ################### UPDATE MODE ######################
            if in_system.include?(tenant["Id"])
              lease_ip = IntegrationProfile.where(integration: integration, external_context: 'lease', external_id: tenant["Id"]).take
              lease = lease_ip.profileable
              # fix basic data
              lease.insurable_id = unit.id
              lease.start_date = Date.parse(tenant["LeaseFrom"]) unless tenant["LeaseFrom"].blank?
              lease.end_date = Date.parse(tenant["LeaseTo"]) unless tenant["LeaseTo"].blank?
              lease.defunct = false # just in case it was once missing from yardi and now is magically back, for example if it got moved to a different unit. likewise, update statuses in case someone defuncted and expired us previously because we jumped units
              lease.sign_date = Date.parse(tenant["LeaseSign"]) unless tenant["LeaseSign"].blank?
              lease.month_to_month = ( lease.start_date && lease.end_date && lease.end_date < lease.start_date && (RESIDENT_STATUSES['present'].include?(tenant['Status']) || RESIDENT_STATUSES['future'].include?(tenant['Status'])) )
              lease.end_date = nil if lease.month_to_month
              lease.status = 'current' if (lease.month_to_month || lease.end_date.nil? || lease.end_date > Time.current.to_date) && RESIDENT_STATUSES['present'].include?(tenant["Status"])
              lease.status = 'pending' if (lease.month_to_month || lease.end_date.nil? || lease.end_date > Time.current.to_date) && RESIDENT_STATUSES['future'].include?(tenant["Status"]) || RESIDENT_STATUSES['potential'].include?(tenant["Status"])
              lease.save if lease.changed?
              fmr = fix_missing(lease, tenant, da_tenants)
              update_errors[tenant["Id"]] = fmr[:errors] unless fmr[:errors].blank?
              next unless fmr[:success] # at least one user was uncreatable; stop processing the lease further, since we need to be able to assume all users are present in the below code
              # we can assume all tenants have corresponding users & lease users & appropriate IPs, if we're here
              # now ensure we update the move in/out dates and primary/lessee statuses
              lease.lease_users.reload.each do |lu|
                ten = da_tenants.find{|t| t["Id"] == lu.integration_profiles.where(integration: integration).take&.external_id }
                next if ten.nil? # can't happen but just in case
                moved_in_at = (Date.parse(ten["MoveIn"]) rescue nil)
                moved_out_at = (Date.parse(ten["MoveOut"]) rescue :broken)
                primary = (tenant["Id"] == ten["Id"])
                lessee = primary || (ten["Lessee"] == "Yes")
                if (lu.moved_in_at != moved_in_at && !moved_in_at.blank?) || (lu.moved_out_at != moved_out_at && moved_out_at != :broken) || (lu.primary != primary) || (lu.lessee != lessee)
                  lu.update({ moved_in_at: moved_in_at, moved_out_at: moved_out_at, primary: primary, lessee: lessee }.select{|k,v| v != :broken })
                end
              end
              # handle ridiculous swaps
              fix_ridiculous_swaps(lease, tenant, da_tenants)
              # skip create mode stuff since the lease was pre-existing
              next 
            end
            ################### CREATE MODE ######################
            next if tenant_index >= noncreatable_start
            if tenant["LeaseFrom"].blank?
              lease_errors[tenant["Id"]] = "Failed to create Lease: LeaseFrom is blank!"
              next
            end
            # create the lease
            month_to_month = (!tenant["LeaseTo"].blank? && ((Date.parse(tenant["LeaseTo"]) rescue nil) || Time.current.to_date) < Time.current.to_date && (RESIDENT_STATUSES['present'].include?(tenant['Status']) || RESIDENT_STATUSES['future'].include?(tenant['Status'])))
            ActiveRecord::Base.transaction(requires_new: true) do
              lease = unit.leases.create(
                start_date: Date.parse(tenant["LeaseFrom"]),
                end_date: tenant["LeaseTo"].blank? || month_to_month ? nil : Date.parse(tenant["LeaseTo"]),
                sign_date: tenant["LeaseSign"].blank? ? nil : Date.parse(tenant["LeaseSign"]),
                month_to_month: month_to_month,
                lease_type_id: LeaseType.residential_id,
                account: integration.integratable
              )
              if lease.id.nil?
                lease_errors[tenant["Id"]] = "Failed to create Lease: #{lease.errors.to_h}"
                next
              end
              da_tenants.each.with_index do |ten, ind|
                userobj = find_or_create_user(tenant, ten)
                if userobj.nil?
                  lease_errors[tenant["Id"]] = "Skipped lease due to user import failures."
                  raise ActiveRecord::Rollback
                end
                lu = lease.lease_users.create(
                  user: userobj,
                  primary: (ind == 0),
                  lessee: (ind == 0 || ten["Lessee"] == "Yes"),
                  moved_in_at: (Date.parse(ten["MoveIn"]) rescue nil),
                  moved_out_at: (Date.parse(ten["MoveOut"]) rescue nil)
                )
                if lu&.id.nil?
                  lease_errors[tenant["Id"]] = "Failed to create Lease due to LeaseUser creation failure for resident '#{ten["Id"]}': #{lu.errors.to_h}"
                  raise ActiveRecord::Rollback
                end
                luip = IntegrationProfile.create!(
                  integration: integration,
                  external_context: "lease_user_for_lease_#{tenant["Id"]}",
                  external_id: ten["Id"],
                  profileable: lu,
                  configuration: { 'synced_at' => Time.current.to_s, 'post_fix_em' => true }
                )
                if luip.id.nil?
                  lease_errors[tenant["Id"]] = "Failed to create Lease due to LeaseUser IntegrationProfile creation failure for resident '#{ten["Id"]}': #{luip.errors.to_h}"
                  raise ActiveRecord::Rollback
                end
              end
              created_leases[tenant["Id"]] = lease
              created_profile = IntegrationProfile.create(
                integration: integration,
                profileable: lease,
                external_context: "lease",
                external_id: tenant["Id"],
                configuration: {
                  'luips_created' => true, # to tell the system we have created lease user integration profiles, since we need to fix those that don't have this property
                  'synced_at' => Time.current.to_s,
                  'external_data' => tenant,
                  'post_fix_em' => true
                }
              )
              if created_profile.id.nil?
                lease_errors[tenant["Id"]] = "Failed to create lease due to IntegrationProfile creation errors: #{created_profile.errors.to_h}"
                raise ActiveRecord::Rollback
              end
            end # end transaction
          end # end lease creation & update logic
          # done
          return({
            lease_update_errors: update_errors,
          
            lease_errors: lease_errors,
            leases_created: created_leases,
            leases_found: found_leases,
            leases_expired: expired_leases,
            
            user_errors: user_errors,
            users_created: created_users,
            users_found: found_users
          })
        end
        
        
        
        
        
      end
    end
  end
end
