json.extract! policy_premium, :id, :total,
  :policy_quote_id, :policy_id

json.total_premium (policy_premium.total_premium + policy_premium.total_hidden_fee + policy_premium.total_hidden_tax)
json.total_fee (policy_premium.total_fee - policy_premium.total_hidden_fee)
json.total_tax (policy_premium.total_tax - policy_premium.total_hidden_tax)
