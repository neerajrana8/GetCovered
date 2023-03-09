json.partial! "v2/public/insurables/insurable_show_fields.json.jbuilder",
  insurable: insurable

json.community_liabiility_coverage_min @min_liability
json.community_contents_coverage_min @max_liability

json.addresses_attributes do
  unless insurable.addresses.nil?
    json.array! insurable.addresses do |insurable_addresses|
      json.partial! "v2/staff_super_admin/addresses/address_show_fields.json.jbuilder",
                    address: insurable_addresses
    end
  end
end

json.active_master_policy do
  if @master_policy.present?
    @mpc = insurable.insurable_type_id == 1 ? @master_policy.find_closest_master_policy_configuration(insurable) : @master_policy.find_closest_master_policy_configuration(insurable.parent_community)
    json.partial! 'v2/shared/policies/fields.json.jbuilder', policy: @master_policy
    json.coverage_attributes do
      #TODO: need to move to one query
      json.master_policy_liability @master_policy.policy_coverages.where(designation: 'liability_coverage').take
      json.master_policy_contents  @master_policy.policy_coverages.where(designation: 'liability_contents').take
      #TODO: need to update when migration will be applied on dev
      json.master_policy_per_month_charge MasterPolicyConfiguration.where(configurable_id: @master_policy.id)&.first&.placement_cost
    end
  end
end

json.active_master_policy_coverage do
  if @master_policy_coverage.present?
    json.partial! 'v2/shared/policies/fields.json.jbuilder', policy: @master_policy_coverage
  end
end

json.account do
  if insurable.account&.present?
    json.id insurable.account.id
    json.title insurable.account.title
    json.additional_interest insurable.account.additional_interest
    json.additional_interest_name insurable.account.additional_interest_name
  end
end

json.account_agency do
  if insurable.account&.agency&.present?
    json.id insurable.account.agency.id
    json.title insurable.account.agency.title
  end
end

json.agency do
  if insurable.agency.present?
    json.id insurable.agency.id
    json.title insurable.agency.title
  end
end

#TODO: need to be removed when move to get_or_create EP
#json.units_attributes do
#  unless insurable.unit?
#    json.array! insurable.units do |unit|
#      json.partial! "v2/staff_super_admin/insurables/insurable_show_fields.json.jbuilder",
#                    insurable: unit
#    end
#  end
#end

json.user_attributes do
  if @user.present?
    json.email @user.contact_email
    json.first_name @user.profile.first_name
    json.last_name @user.profile.last_name
  end
end

json.primary_insurable_attributes do
  if @user.present?
    if @user.latest_lease.insurable.parent_building.present?
      json.building do
        json.partial! "v2/staff_super_admin/insurables/insurable_show_fields.json.jbuilder",
                          insurable: @user.latest_lease.insurable.parent_building
      end
    end

    json.unit do
        json.partial! "v2/staff_super_admin/insurables/insurable_show_fields.json.jbuilder",
                      insurable: @user.latest_lease.insurable
    end
  end
end


json.debug do
  json.master_policy @master_policy
end
