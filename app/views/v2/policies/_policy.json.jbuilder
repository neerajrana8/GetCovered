json.cache! policy do
  json.extract! policy, :account_id, :agency_id, :auto_pay, :auto_renew,
                :billing_behind_since, :billing_enabled, :billing_status,
                :cancellation_date, :created_at, :effective_date, :expiration_date, :id,
                :last_renewed_on, :number, :policy_in_system, :policy_type_id,
                :renew_count, :updated_at, :status, :out_of_system_carrier_title, :address


  json.account do
    if policy.account.present?
      json.title policy.account&.title
    else
      json.title policy.insurables&.last&.account&.title
    end
  end

  json.carrier do
    json.title policy.carrier&.title
  end

  json.agency do
    if policy.agency.present?
      json.title policy.agency&.title
    else
      if policy.insurables&.last&.agency.present?
        json.title policy.insurables&.last&.agency&.title
      else
        json.title policy.insurables&.last&.account&.agency&.title
      end
    end
  end

  json.policy_type_title policy&.policy_type&.title


  json.primary_insurable do
    unless policy.primary_insurable.nil?
      json.partial! "v2/policies/primary_insurable",
                    insurable: policy.primary_insurable
      json.parent_community do
        if policy.primary_insurable.parent_community_for_all.present?
          json.partial! 'v2/policies/primary_insurable',
                        insurable: policy.primary_insurable.parent_community_for_all
        end
      end
      json.parent_building do
        if policy.primary_insurable.parent_building.present?
          json.partial! 'v2/policies/primary_insurable',
                        insurable: policy.primary_insurable.parent_building
        end
      end
    end
  end


  json.primary_user do
    if policy.primary_user.present?
      json.email policy.primary_user.email
      json.full_name policy.primary_user.profile&.full_name
    end
  end
  json.billing_strategy policy.policy_quotes&.last&.policy_application&.billing_strategy&.title

  if policy&.primary_policy_user&.integration_profiles.present?
    json.tcode policy&.primary_policy_user&.integration_profiles&.first&.external_id
  end

end
