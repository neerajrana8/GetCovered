json.array! @stripe_charges,
  partial: 'v2/staff_super_admin/stripe_charges/stripe_charge_short_full.json.jbuilder',
  as: :stripe_charge
