json.extract! payment, :id, :status, :amount,
                       :invoice_id, :created_at, :updated_at

json.invoice do
  json.partial! "v2/staff_super_admin/invoices/invoice_short_full",
    invoice: payment.invoice

  json.user do
    json.partial! "v2/staff_super_admin/users/user_short_full", 
      user: payment.invoice.user
  end unless payment.invoice.user.nil?

  json.policy do
    json.partial! "v2/staff_super_admin/policies/policy_short_full", 
      policy: payment.invoice.policy
  end unless payment.invoice.policy.nil?
end unless payment.invoice.nil?
