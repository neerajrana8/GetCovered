json.array! @stripe_charges,
  partial: 'v2/user/stripe_charges/stripe_charge_short_full.json.jbuilder',
  as: :stripe_charge
