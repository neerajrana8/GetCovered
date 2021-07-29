json.partial! "v2/staff_super_admin/stripe_charges/stripe_charge_show_fields.json.jbuilder",
  stripe_charge: stripe_charge


json.disputes do
  unless stripe_charge.disputes.nil?
    json.array! stripe_charge.disputes do |stripe_charge_disputes|
      json.partial! "v2/staff_super_admin/disputes/dispute_show_full.json.jbuilder",
        dispute: stripe_charge_disputes
    end
  end
end

# stripe refund view not yet implemented
#
#json.stripe_refunds do
#  unless stripe_charge.stripe_refunds.nil?
#    json.array! stripe_charge.stripe_refunds do |stripe_charge_stripe_refunds|
#      json.partial! "v2/staff_super_admin/stripe_refunds/stripe_refund_show_full.json.jbuilder",
#        stripe_refund: stripe_charge_stripe_refunds
#    end
#  end
#end
