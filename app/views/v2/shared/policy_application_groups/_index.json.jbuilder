json.partial! 'v2/shared/policy_application_groups/fields.json.jbuilder',
              policy_application_group: policy_application_group

json.policy_group_quote do
  unless policy_application_group.policy_group_quote.blank?
    json.partial! 'v2/shared/policy_group_quotes/fields.json.jbuilder',
                  policy_group_quote: policy_application_group.policy_group_quote
    json.policy_group_premium do
      unless policy_application_group.policy_group_quote.policy_group_premium.blank?
        json.partial! 'v2/shared/policy_group_premiums/fields.json.jbuilder',
                      policy_group_premium: policy_application_group.policy_group_quote.policy_group_premium
      end
    end
  end
end

json.policy_group do
  if policy_application_group.policy_group.present?
    json.partial! 'v2/shared/policy_groups/fields.json.jbuilder',
                  policy_group: policy_application_group.policy_group
  end
end
