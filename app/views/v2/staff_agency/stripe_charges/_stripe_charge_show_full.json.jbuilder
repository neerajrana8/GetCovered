json.partial! "v2/staff_agency/charges/charge_show_fields.json.jbuilder",
  charge: charge


json.disputes do
  unless charge.disputes.nil?
    json.array! charge.disputes do |charge_disputes|
      json.partial! "v2/staff_agency/disputes/dispute_show_full.json.jbuilder",
        dispute: charge_disputes
    end
  end
end

# stripe refund view not yet implemented
#
#json.stripe_refunds do
#  unless charge.stripe_refunds.nil?
#    json.array! charge.stripe_refunds do |charge_stripe_refunds|
#      json.partial! "v2/staff_agency/stripe_refunds/stripe_refund_show_full.json.jbuilder",
#        stripe_refund: charge_stripe_refunds
#    end
#  end
#end
