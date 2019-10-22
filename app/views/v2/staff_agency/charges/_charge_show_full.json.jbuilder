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

json.refunds do
  unless charge.refunds.nil?
    json.array! charge.refunds do |charge_refunds|
      json.partial! "v2/staff_agency/refunds/refund_show_full.json.jbuilder",
        refund: charge_refunds
    end
  end
end
