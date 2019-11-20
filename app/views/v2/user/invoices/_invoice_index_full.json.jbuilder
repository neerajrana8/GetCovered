json.partial! 'v2/user/invoices/invoice_index_fields.json.jbuilder',
  invoice: invoice

json.policy do
  if invoice.policy.present?
    json.partial! 'v2/user/policies/policy_short_fields.json.jbuilder', policy: invoice.policy
  end
end
