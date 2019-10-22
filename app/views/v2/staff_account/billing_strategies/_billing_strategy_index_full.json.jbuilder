json.partial! "v2/staff_account/billing_strategies/billing_strategy_index_fields.json.jbuilder",
  billing_strategy: billing_strategy


json.carrier do
  unless billing_strategy.carrier.nil?
    json.partial! "v2/staff_account/carriers/carrier_short_fields.json.jbuilder",
      carrier: billing_strategy.carrier
  end
end
