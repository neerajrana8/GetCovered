json.partial! "v2/staff_super_admin/charges/charge_show_fields.json.jbuilder",
  charge: charge


json.disputes do
  unless charge.disputes.nil?
    json.array! charge.disputes do |charge_disputes|
      json.partial! "v2/staff_super_admin/disputes/dispute_show_full.json.jbuilder",
        dispute: charge_disputes
    end
  end
end

json.refunds do
  unless charge.refunds.nil?
    json.array! charge.refunds do |charge_refunds|
      json.partial! "v2/staff_super_admin/refunds/refund_show_full.json.jbuilder",
        refund: charge_refunds
    end
  end
end
