json.partial! "v2/user/claims/claim_index_fields.json.jbuilder",
  claim: claim


json.insurable do
  unless claim.insurable.nil?
    json.partial! "v2/user/insurables/insurable_short_fields.json.jbuilder",
      insurable: claim.insurable
  end
end

json.policy do
  unless claim.policy.nil?
    json.partial! "v2/user/policies/policy_short_fields.json.jbuilder",
      policy: claim.policy
  end
end
