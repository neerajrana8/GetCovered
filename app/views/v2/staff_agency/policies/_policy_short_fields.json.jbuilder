json.extract! policy, :effective_date, :expiration_date, :id, :number,
  :out_of_system_carrier_title
json.policy_type_title policy&.policy_type&.title
