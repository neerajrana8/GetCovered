json.partial! 'v2/user/policy_applications/policy_application_show_fields.json.jbuilder',
              policy_application: policy_application

json.account do
  unless policy_application.account.nil?
    json.partial! 'v2/user/accounts/account_short_fields.json.jbuilder',
                  account: policy_application.account
  end
end

json.agency do
  unless policy_application.agency.nil?
    json.partial! 'v2/user/agencies/agency_short_fields.json.jbuilder',
                  agency: policy_application.agency
  end
end

json.carrier do
  unless policy_application.carrier.nil?
    json.partial! 'v2/user/carriers/carrier_short_fields.json.jbuilder',
                  carrier: policy_application.carrier
  end
end

json.invoices do
  if policy_application.policy_quotes.last&.invoices&.any?
    json.array! policy_application.policy_quotes.last.invoices,
                partial: 'v2/shared/invoices/fields.json.jbuilder',
                as: :invoice
  end
end

json.policy_quote do
  if policy_application.policy_quotes.last.present?
    json.partial! 'v2/user/policy_quotes/policy_quote_show_full.json.jbuilder',
                  policy_quote: policy_application.policy_quotes.last
  end
end
