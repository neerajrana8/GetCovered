
module Reporting
  class Reporting::PolicyEntry < ApplicationRecord
    self.table_name = "reporting_policy_entries"

    belongs_to :account
    belongs_to :policy
    belongs_to :lease,
      optional: true
    belongs_to :community,
      class_name: "Insurable",
      foreign_key: :community_id
    belongs_to :unit,
      class_name: "Insurable",
      foreign_key: :unit_id

    # ways things can change:
    #   1) insurable can change, policy status can change, etc.
    #   2) user can change (particularly due to merger)
    #   3) user can get a new integration profile
    #   4) lease status can change, lease user can move out, lease can get created
    def self.sync(account)
      # grab entries that might should be updated due to policy or insurable changes (1)
      ids = Reporting::PolicyEntry.references(policies: :policy_insurables).includes(policy: :policy_insurables)
        .where("reporting_policy_entries.updated_at < greatest(policies.updated_at, policy_insurables.updated_at)")
        .where(account: account, policy_insurables: { primary: true }, policies: {
          policy_type_id: 1
        }
      ).pluck("reporting_policy_entries.id")
      ids.each do |id|
        Reporting::PolicyEntry.find(id).refresh!
      end
      # grab entries that might should be updated due to new integration profile (2, 3)
      ids = Reporting::PolicyEntry.references(policies: :policy_users).includes(policy: :policy_users)
                       .joins("INNER JOIN integration_profiles ON integration_profiles.profileable_id = policy_users.user_id AND integration_profiles.profileable_type = 'User'")
                       .where(account: account)
                       .where(integration_profiles: {
                          integration_id: account.integrations.where(provider: "yardi").select(:id),
                          external_context: "resident"
                       })
                       .where("reporting_policy_entries.updated_at < greatest(policy_users.updated_at, integration_profiles.updated_at, integration_profiles.created_at)")
                       .where(policies: {
                         policy_type_id: 1
                       }).pluck("reporting_policy_entries.id").uniq
      ids.each do |id|
        Reporting::PolicyEntry.find(id).refresh!
      end
      # lease status changes, creations, etc.
      ids = Reporting::PolicyEntry.references(insurables: { leases: :lease_users }).includes(unit: { leases: :lease_users })
                       .where(account: account)
                       .where("reporting_policy_entries.updated_at < greatest(leases.updated_at, leases.created_at, lease_users.updated_at, lease_users.created_at)")
                       .pluck("reporting_policy_entries.id").uniq
      ids.each do |id|
        Reporting::PolicyEntry.find(id).refresh!
      end
      # grab policies that need new entries
      ids = PolicyInsurable.references(:policies).includes(:policy)
              .where.not(policy_id: Reporting::PolicyEntry.where(account: account).select(:policy_id))
              .where(
                primary: true,
                insurable: account.insurables.where(insurable_type_id: ::InsurableType::RESIDENTIAL_UNITS_IDS).confirmed
              ).select(:policy_id)
              .where(policies: {
                policy_type_id: 1
              }).pluck(:policy_id)
      ids.each do |id|
        params = self.extract_params(account, id)
        Reporting::PolicyEntry.create(params) unless params.nil?
      end
    end
    
    def self.extract_params(account, policy_id)
      # prepare
      policy = Policy.where(id: policy_id).take
      return nil if policy.nil?
      unit_ip = policy.primary_insurable.integration_profiles.references(:integrations).includes(:integration)
        .where(integrations: { provider: 'yardi', integratable_type: "Account", integratable_id: account.id })
        .where("integration_profiles.external_context ILIKE 'unit_in_community_%'")
        .take
      address = policy.primary_insurable.primary_address
      lease = policy.latest_lease(user_matches: true, lessees_only: true, current_only: true)
      # get basic params
      params = {
        account_title: account.title,
        account_id: policy.primary_insurable&.account_id || policy.account_id,
        number: policy.number,
        yardi_property: unit_ip&.external_context&.split("_")&.last,
        community_title: policy.primary_insurable.parent_community.title,
        yardi_unit: unit_ip&.external_id,
        unit_title: policy.primary_insurable.title,
        street_address: address.combined_street_address,
        city: address.city,
        state: address.state,
        zip: address.zip_code,
        carrier_title: policy.carrier&.title || policy.out_of_system_carrier_title,
        yardi_lease: lease&.integration_profiles&.references(:integrations)&.includes(:integration)
          &.where(integrations: { provider: 'yardi', integratable_type: "Account", integratable_id: account.id })
          &.where(external_context: "lease")&.take&.external_id,
        lease_status: lease&.status,
        effective_date: policy.effective_date,
        expiration_date: policy.cancellation_date || policy.expiration_date,
        policy_id: policy.id,
        lease_id: lease&.id,
        community_id: policy.primary_insurable.parent_community.id,
        unit_id: policy.primary_insurable.id,
        primary_policyholder_first_name: policy.primary_user&.profile&.first_name,
        primary_policyholder_last_name: policy.primary_user&.profile&.last_name,
        primary_lessee_first_name: lease&.primary_user&.profile&.first_name,
        primary_lessee_last_name: lease&.primary_user&.profile&.last_name,
        primary_policyholder_email: policy.primary_user&.email || policy.primary_user&.profile&.contact_email,
        primary_lessee_email: lease&.primary_user&.email || lease&.primary_user&.profile&.contact_email,
        expires_before_lease: !lease.nil? && (lease.end_date ? policy.expiration_date <= lease.end_date : policy.expiration_date < lease.start_date),
        applies_to_lessee: !lease.nil?
      }
      # get any_email
      any_email = params[:primary_lessee_email] ||
        lease&.active_users(lessee: true)&.find{|u| u.email || u.profile&.contact_email }
      any_email = (any_email.email || any_email.profile&.contact_email) if any_email.class == ::User
      params[:any_lessee_email] = any_email
      # all done!
      return(params)
    end
    
    def refresh!
      params = self.class.extract_params(self.account, self.policy_id)
      self.update(params)
    end


  end # end class
end
