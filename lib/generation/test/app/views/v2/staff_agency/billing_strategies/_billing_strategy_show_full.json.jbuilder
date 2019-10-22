json.partial! "v2/staff_agency/billing_strategies/billing_strategy_show_fields.json.jbuilder",
  billing_strategy: billing_strategy


json.agency do
  unless billing_strategy.agency.nil?
    json.partial! "v2/staff_agency/agencies/agency_short_fields.json.jbuilder",
      agency: billing_strategy.agency
  end
end

json.carrier do
  unless billing_strategy.carrier.nil?
    json.partial! "v2/staff_agency/carriers/carrier_short_fields.json.jbuilder",
      carrier: billing_strategy.carrier
  end
end
