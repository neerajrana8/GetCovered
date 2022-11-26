





# users that actually exist with an ip User.where(id: IntegrationProfile.where(profileable_type: "User").select(:profileable_id))
# ips that exist without a user: IntegrationProfile.where(profileable_type: "User").where.not(profileable_id: User.where(id: IntegrationProfile.where(profileable_type: "User").select(:profileable_id)).select(:id)).count
# zero, thank god




def get_da_tenants(lease_ip)
  tenant = lease_ip.configuration['external_data']
  return [tenant] + (tenant["Roommate"].nil? ? [] : tenant["Roommate"].class == ::Array ? tenant["Roommate"] : [tenant["Roommate"]])
end
# MOOSE WARNING: change default user_ids to nil for safety once working


def fix_em(user_ids = IntegrationProfile.where(profileable_type: "User").order(profileable_id: :asc).pluck(:profileable_id).uniq, do_it_for_real: false)
  ActiveRecord::Base.logger.level = 1
  if do_it_for_real
    IntegrationProfile.where(profileable_type: "LeaseUser").delete_all
  end
  $counts = {
    users: 0,
    users_with_multiple_identities: 0,
    users_with_multiple_units: 0,
    users_with_multiple_distinct_identities: 0,
    policies_that_might_change: {},
    deleted_orphaned_uips: []
  }
  manual_user_mappings = {  
    12148 => "amy cohen",
    17606 => "samantha liebman",
    53335 => "louisa steinhafel",
    48014 => "aastha p shah",
    6042 => "santiago andres lopez lugo",
    50128 => "peter a ajayi",
    42771 => "elematec usa corporation",
    10517 => "cory ludwig",
    41877 => "misao masuyama",
    36960 => "benjamin brun",
    48584 => "ankit kumar",
    9244 => "alef edge, inc.",
    34134 => "patricio ruperto troncoso ortiz",
    38286 => "nicholas frattaroli",
    10645 => "joseph giordano",
    10795 => "diarmuid dwyer",
    55532 => "najibullah mohmand",
    52213 => "brittany goldberger",
    36875 => "alexander colborn",
    36906 => "clare delaurentis",
    52296 => "robert hooper",
    52365 => "allison kleinman",
    52393 => "jonathan gaelen",
    52413 => "dana greenawald",
    37170 => "christoper fisher",
    37200 => "kelly poulsen",
    37214 => "kenneth mirkin",
    37215 => "stephen gallagher",
    9216 => "cynthia yoder",
    53289 => "zoe berkovic",
    53486 => "mackenzie o'connor",
    37415 => "nicole ebanks",
    9388 => "lerner rodrigues",
    37683 => "peter nobes",
    53636 => "elizabeth albanese",
    12600 => "erik wrolstad",
    15618 => "anthonios kountouris",
    36587 => "sangita shah",
    13740 => "christopher maddern",
    12943 => "christopher mccarthy",
    7002 => "conor ryan",
    15321 => "aidan sumner",
    54511 => "emmanuel uzomah",
    21853 => "stellar stays inc. #3305 represented by nehemiah ladner"
  }
  user_ids ||= User.where(id: IntegrationProfile.where(profileable_type: "User").select(:profileable_id)).pluck(:id)
  user_ids.each.with_index do |user_id, indie_boi|
    puts "Behold! We shall now begin to process User #{user_id}."
    $counts[:users] += 1
    user = User.find(user_id)
    $counts[:users_with_multiple_identities] += 1 if user.integration_profiles.count > 1
    mutable = !(user.sign_in_count > 0)
    user.profile.update(first_name: user.profile.first_name.strip, last_name: user.profile.last_name.strip) # just in case, I found some weird whitespace in some
    lips = IntegrationProfile.where(profileable: user.leases).to_a.uniq
    $counts[:users_with_multiple_units] += 1 if lips.map{|l| l.profileable.insurable_id }.uniq.count > 1
    # get residents this user represents
    orphaned_uips = [] # UIPs not matching any of the user's leases
    residents = user.integration_profiles.map do |uip|
      lip = lips.find{|lip| get_da_tenants(lip).any?{|ten| ten["Id"] == uip.external_id } }
      if lip.nil?
        orphaned_uips.push(uip)
        next nil
      end
      ten = get_da_tenants(lip).find{|ten| ten["Id"] == uip.external_id }
      next {
        uip: uip,
        lip: lip,
        primary: (ten == lip.configuration['external_data']),
        lessee: (ten == lip.configuration['external_data'] || ten["Lessee"] == "Yes")
      }
    end.compact
    # get leases with the same insurable as each policy
    orphaned_policies = [] # policies not matching any of the user's leases
    policy_ids_to_lease_ids = user.policies.uniq.map do |pol|
      tr = [
        pol.id,
        user.leases.select{|l| l.insurable_id == pol.primary_insurable.id }.sort_by{|l| l.status == 'pending' ? 0 : l.start_date.to_time.to_i }.reverse.map{|l| l.id }
      ]
      if tr[1].blank?
        orphaned_policies.push(pol)
        next nil
      end
      next tr
    end.compact.to_h
    # decide on the treatment of orphans
    let_the_orphans_stand_condemned = false
    if orphaned_uips.count > 0
      if !mutable || orphaned_policies.count > 0
        # in these cases we need to ensure that the leases that may have LU or LUIPs
        # missing connecting to this user connect properly on the next import, so we can't kill the orphans;
        # we leave the UIPs untouched (we put a tag on uips we touch later on, so we can still tell these apart later),
        # i.e. we do nothing here
      else
        # in this case there is no need for the leases not connected to connect to this same user later; we can simply remove the orphans
        let_the_orphans_stand_condemned = true
        unless do_it_for_real
          $counts[:deleted_orphaned_uips].concat(orphaned_uips.map{|o| o.id })
        end
      end
    end
    # handle folk with no residents (only orphaned UIPs)
    if residents.blank?
      if orphaned_uips.count == 1
        # no need to do anything, except remove the email key and mark the orphan processed
        if do_it_for_real
          if user.provider == 'email' && mutable
            user.profile.update!(contact_email: user.email)
            user.provider = 'altuid'
            user.altuid = "FE" + Time.current.to_i.to_s + rand.to_s
            user.uid = user.altuid
            saved = user.save!
          end
          orphaned_uips.first.update!(configuration: orphaned_uips.first.configuration.merge({ 'from_fix_em' => 'UCTNR' }))
          # in the multiple case below, we would run this if we weren't leaving it as a debug exit since it never occurs, but here
          # we don't destroy the orphan even if we normally would. since there is 1 orphan and 0 residents, there has been no opportunity for two users to be merged here
          #if let_the_orphans_stand_condemned
          #  orphaned_uips.each{|o| o.delete }
          #end
          puts "Completed #{user_id} (#{indie_boi} / #{user_ids.count}). Special completion: User corresponded to no residents (UCTNR); spared the orphan IntegrationProfile #{orphaned_uips.first.id}."
        end
        next
      else
        # we just leave if this happens, because in testing we found it never happens; but it should be fine if  needed to
        # replace this with the previous case, except do not force-preserve the orphans & if no orphans remain the user itself can be deleted if you want (if mutable, obviously)
        puts "No Yardi residents corresponding to #{user_id} and it has multiple orphaned UIPs! (#{mutable ? "mutable" : "immutable"})"
        puts "  orphaned uips: #{orphaned_uips.map{|u| u.id }}"
        puts "  lease users:   #{user.lease_users.count}"
        puts "  policy users:  #{user.policy_users.count}"
        break
      end
    end
    # move residents into groups that ACTUALLY represent the same user
    resident_groups = []
    residents.each do |res|
      da_tenants = get_da_tenants(res[:lip])
      ten = da_tenants.find{|dt| dt["Id"] == res[:uip].external_id }
      match = resident_groups.find{|rg| rg[:first_name] == ten["FirstName"]&.strip&.downcase && rg[:last_name] == ten["LastName"]&.strip&.downcase }
      if match.nil?
        resident_groups.push(res[:group] = {
          first_name: ten["FirstName"]&.strip&.downcase,
          last_name: ten["LastName"]&.strip&.downcase,
          og_first_name: ten["FirstName"].blank? ? "Unknown" : ten["FirstName"],
          og_last_name: ten["LastName"].blank? ? "Unknown" : ten["LastName"],
          residents: [res]
        })
      else
        res[:group] = match
        match[:residents].push(res)
      end
      res[:group][:email] ||= ten["Email"] unless ten["Email"].blank? # they should all have the same email as user, since that is why they are merged in the first place; but we might as well grab it from the yardi records just in case we're insane and forgetting an edge case
    end
    if resident_groups.count > 1
      $counts[:users_with_multiple_distinct_identities] += 1
      unless do_it_for_real
        user.policies.each do |p|
          $counts[:policies_that_might_change][p.number] = true
        end
      end
    end
    # figure out which group the user should actually belong to
    true_group = if resident_groups.count == 1
      resident_groups.first
    elsif manual_user_mappings.has_key?(user_id)
      resident_groups.find{|rg| "#{rg[:first_name]&.strip&.downcase} #{rg[:last_name]&.strip&.downcase}"&.strip&.downcase == manual_user_mappings[user_id] }
    else
      nil
    end
    if true_group.nil?
      resident_groups.find{|rg| rg[:first_name]&.strip&.downcase == user.profile.first_name&.strip&.downcase && rg[:last_name]&.strip&.downcase == user.profile.last_name&.strip&.downcase }
    end
    if true_group.nil?
      goombas = resident_groups.select{|rg| "#{rg[:first_name]&.strip&.downcase} #{rg[:last_name]&.strip&.downcase}".index(user.profile.first_name&.strip&.downcase) && "#{rg[:first_name]&.strip&.downcase} #{rg[:last_name]&.strip&.downcase}".index(user.profile.last_name&.strip&.downcase) }
      if goombas.count == 1 || (goombas.count > 1 && mutable)
        true_group = goombas.first
      else
        goombas = resident_groups.select{|rg| "#{rg[:first_name]&.strip&.downcase} #{rg[:last_name]&.strip&.downcase}".index(user.profile.first_name&.strip&.split&.[](0)&.strip&.downcase) && "#{rg[:first_name]&.strip&.downcase} #{rg[:last_name]&.strip&.downcase}".index(user.profile.last_name&.strip&.split&.[](0)&.strip&.downcase) }
        if goombas.count == 1 || (goombas.count > 1 && mutable)
          true_group = goombas.first
        else
          if mutable
            goombas = resident_groups.select{|rg| "#{rg[:first_name]&.strip&.downcase} #{rg[:last_name]&.strip&.downcase}".index(user.profile.first_name&.strip&.split&.first&.strip&.downcase) && "#{rg[:first_name]&.strip&.downcase} #{rg[:last_name]&.strip&.downcase}".index(user.profile.last_name&.strip&.split&.last&.strip&.downcase) }
            if goombas.count == 1
              true_group = goombas.first
            end
          end
        end
      end
    end
    true_group[:true_user] = true unless true_group.nil?
    # verify that a true group was found
    # MOOSE WARNING: we ran this several times with do_it_for_real set to false and put together the manual_user_mappings hash using this;
    #  the code expects you to ensure this isn't the case if you want it to run without aborting
    if true_group.nil?
      puts "#{user_id}: #{user.profile.full_name} (#{mutable ? "mutable" : "immutable"})"
      resident_groups.each do |rg|
        puts "  #{rg[:first_name]} #{rg[:last_name]}"
      end
      if do_it_for_real
        puts "Aborted due to failure to identify among the associated Yardi users anyone with the same name as user #{user_id}."
        break
      else
        next
      end
    end
    # map each lipped lease to its resident groups (entries here represent Users that we are splitting the current user into, with uips representing independent LeaseUsers)
    leases_to_groups = []
    if resident_groups.count == 1
      lips.each{|lip| leases_to_groups.push({ lease: lip.profileable, group: resident_groups.first }) }
    else
      lips.each do |lip|
        resident_groups.select{|g| g[:residents].any?{|r| r[:lip].id == lip.id } }.each do |rg|
          leases_to_groups.push({
            lease: lip.profileable,
            group: rg
          })
        end
      end
    end
    # map policy users to resident groups
    policy_users_to_groups = {}
    if resident_groups.count == 1
      policy_users_to_groups = user.policy_users.map{|pu| [pu.id, resident_groups.first] }.to_h
    else
      policy_ids_to_lease_ids.each do |policy_id, lease_ids|
        pol = Policy.find(policy_id)
        internal_policy = !(pol.policy_application.nil?)
        # build candidates in order of preference
        temp = lease_ids.map{|lid| residents.select{|r| r[:lip].profileable_id == lid }.sort_by{|x| x[:primary] ? 0 : x[:lessee] ? 1 : 2 } }.select{|x| !x.blank? }
        # could do it like this to strafe primaries, but choosing the newest current lease is our best bet for getting it right.
        # btw, I checked before writing this and the only policies with redundant users are [13462, 13467, 12673, 12684, 6991, 42, 13448], so this is a non-issue except in cases where there are multiple leases on the same property with different primary leaseholders
        # candidates = temp.map{|t| t.select{|x| x[:primary] } }.flatten + temp.map{|t| t.select{|x| !x[:primary] && x[:lessee] } }.flatten + temp.map{|t| t.select{|x| !x[:primary] && !x[:lessee] } }.flatten
        candidates = temp.flatten
        candidates = candidates.map{|c| c[:group] }.uniq
        candidates = [true_group] if candidates.count == 0
        temp = candidates.first
        # assign policy users
        user.policy_users.where(policy_id: policy_id).sort_by{|x| x.primary ? 0 : 1 }.each do |pu|
          if !mutable && pu.primary && internal_policy # an internal policy bought by this user  
            policy_users_to_groups[pu.id] = true_group
            candidates.select!{|c| c != true_group }
            next
          end
          if candidates.count > 0
            policy_users_to_groups[pu.id] = candidates.shift
          else
            policy_users_to_groups[pu.id] = temp # fall back to the best candidate if we must
          end
        end
      end
    end
    # now resident_groups represents our users, resident_group[:residents] represents our lease users, and policy_users_to_groups represents our policy users
    # the remaining problems are (1) orphaned uips, (2) orphaned policies, and (3) deciding what heir users to leave with an email and what heir users we don't
    # for 1/2, we are going to just leave them sitting on the main user untouched (unless the user has not logged in & has no orphaned policies but has orphaned UIPs, in which case we delete them (see where we set the delete flag for explanation)
    # for 3, we are going to get rid of emails as primary key for everyone except for immutable users, i.e. people who have already logged in;
    # we will go back through and try to make primary leaseholders use email as primary key or use special invites or something else later
    if do_it_for_real
      success = false
      ActiveRecord::Base.transaction do
        resident_groups.each do |rg|
          # cil old krapp
          user.lease_users.where(lease_id: lips.map{|l| l.profileable_id }).each{|lu| lu.integration_profiles.delete_all }
          user.lease_users.where(lease_id: lips.map{|l| l.profileable_id }).delete_all
          if let_the_orphans_stand_condemned
            orphaned_uips.each{|o| o.delete }
          end
        end
        # we kill stuff in a separate loop because otherwise we can get uniqueness violations
        resident_groups.each do |rg|
          # get or create user for resident group
          if rg[:true_user]
            if mutable
              user.profile.update(contact_email: user.email, first_name: rg[:og_first_name], last_name: rg[:og_last_name])
              user.provider = 'altuid'
              user.altuid = "FE" + Time.current.to_i.to_s + rand.to_s
              user.uid = user.altuid
              unless user.save
                user.altuid = "FE" + Time.current.to_i.to_s + rand.to_s
                user.uid = user.altuid
                user.save!
              end
            end
            rg[:user] = user
          else
            rg[:user] = ::User.create_with_random_password(email: nil, profile_attributes: {
              first_name: rg[:og_first_name],
              last_name: rg[:og_last_name],
              contact_email: rg[:email]
            }.compact)
            if rg[:user].id.nil?
              rg[:user].save! # create failed, trigger error
            end
          end
          # move uips & set up lease users
          rg[:residents].each do |r|
            lu = LeaseUser.create!(
              user: rg[:user],
              lease: r[:lip].profileable,
              primary: r[:primary],
              lessee: r[:lessee]
            )
            luip = IntegrationProfile.create!(
              integration: r[:lip].integration,
              external_context: "lease_user_for_lease_#{r[:lip].configuration['external_data']["Id"]}",
              external_id: r[:uip].external_id,
              profileable: lu,
              configuration: { 'synced_at' => Time.current.to_s, 'from_fix_em' => true }
            )
            r[:uip].update!(profileable: rg[:user], configuration: (r[:uip].configuration || {}).merge({ 'from_fix_em' => true }))
          end
        end
        policy_users_to_groups.each do |pu_id, rg|
          PolicyUser.find(pu_id).update!(user_id: rg[:user].id)
        end
        success = true
      end # end transaction
      if success
        puts "Completed #{user_id} (#{indie_boi} / #{user_ids.count})."
      end
    end # end if do it for real




  end # end user_id loop
  # uncomment if you want a count instead of a hell hash of policy numbers: $counts[:policies_that_might_change] = $counts[:policies_that_might_change].count unless do_it_for_real
  nil
end
















































