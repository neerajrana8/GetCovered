json.partial! 'v2/staff_account/policies/policy_show_fields.json.jbuilder', policy: unit_policy

json.tenant do
  if unit_policy.primary_user.present?
    json.partial! 'v2/staff_account/users/user_show_full.json.jbuilder', user: unit_policy.primary_user
  end
end

json.insurable do
  if unit_policy.insurables.any?
    json.insurable unit_policy.insurables.last
  end
end
