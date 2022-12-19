json.partial! 'v2/shared/leases/fields.json.jbuilder', lease: lease

json.account do
  unless lease.account.nil?
    json.partial! 'v2/staff_super_admin/accounts/account_short_fields.json.jbuilder',
                  account: lease.account
  end
end

json.agency lease&.account&.agency

json.insurable do
  if lease.insurable.present?
    json.partial! 'v2/shared/insurables/index_partial.json.jbuilder',
                  insurable: lease.insurable
  end
end

json.lease_type do
  unless lease.lease_type.nil?
    json.partial! 'v2/staff_super_admin/lease_types/lease_type_short_fields.json.jbuilder',
                  lease_type: lease.lease_type
  end
end

json.users do
  json.array! lease.lease_users.each do |lease_user|
    json.partial! 'v2/staff_super_admin/users/user_show_full.json.jbuilder', user: lease_user.user if lease_user.present?
    json.lessee lease_user.lessee
    json.moved_in_at lease_user.moved_in_at
    json.moved_out_at lease_user.moved_out_at
    if lease_user.user.integration_profiles.present?
      json.t_code lease_user.user&.integration_profiles&.first&.external_id
    end
    json.primary lease_user.primary
  end
end

json.policies do
  if lease.insurable.policies.present?
    json.array! lease.insurable.policies.each do |policy|
      json.extract! policy, :id, :number, :policy_type_id, :status

      json.policy_type_title policy&.policy_type&.title
    end
  end
end

json.master_policy_configurations lease.insurable&.parent_community&.master_policy_configurations
