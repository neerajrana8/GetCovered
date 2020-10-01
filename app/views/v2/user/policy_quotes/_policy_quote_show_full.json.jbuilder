json.partial! "v2/user/policy_quotes/policy_quote_show_fields.json.jbuilder",
  policy_quote: policy_quote

json.premium do
  if policy_quote.policy_premium.present?
    json.partial! 'v2/user/policy_premia/policy_premium_show_full.json.jbuilder',
                  policy_premium: policy_quote.policy_premium
  end
end
