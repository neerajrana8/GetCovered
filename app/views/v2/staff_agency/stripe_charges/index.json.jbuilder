json.array! @stripe_charges,
  partial: 'v2/staff_agency/stripe_charges/stripe_charge_index_full.json.jbuilder',
  as: :stripe_charge
