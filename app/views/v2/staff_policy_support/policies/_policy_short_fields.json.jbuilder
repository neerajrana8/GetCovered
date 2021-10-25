json.extract! policy, :id, :number, :effective_date, :expiration_date, :created_at

json.policy_type_title policy&.policy_type&.title

