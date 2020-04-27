json.partial! 'v2/shared/policy_application_groups/fields.json.jbuilder',
              policy_application_group: @policy_application_group

json.errors do
  if @policy_application_group.all_errors_any?
    json.array! @policy_application_group.all_errors,
                partial: 'v2/shared/model_errors/fields.json.jbuilder',
                as: :model_error
  end
end
