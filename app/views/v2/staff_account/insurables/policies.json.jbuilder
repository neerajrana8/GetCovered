json.array! @policies do |policy|
  json.extract! policy, :id, :number, :billing_status, :effective_date, :expiration_date, :status, :agency_id,
                :account_id, :carrier_id
  json.policy_type policy.policy_type
end
