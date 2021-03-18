module DashboardMethods
  extend ActiveSupport::Concern

  included do
    def communities_data
      index(:@communities_relation, communities, :account)

      @communities_data = @communities_relation.map do |community|
        {
          id: community.id,
          title: community.title,
          account_title: community.account&.title,
          total_units: community.units_relation.count,
          uninsured_units: uninsured_units_count(community),
          expiring_policies: expiring_policies_count(community)
        }
      end

      render template: 'v2/shared/dashboard/communities_data', status: :ok
    end

    private

    def uninsured_units_count(community)
      without_policies = community.
        units_relation.
        joins('LEFT JOIN policy_insurables ON policy_insurables.id = insurables.id').
        where(policy_insurables: { id: nil }).select('insurables.id').
        distinct.count

      with_inactive_policies = community.
        units_relation.
        joins(:policies).
        where(policies: { status: Policy.active_statuses }).
        select('insurables.id').
        distinct.count

      without_policies + with_inactive_policies
    end

    def expiring_policies_count(community)
      community.
        units_relation.
        joins(:policies).
        where(policies: { status: Policy.active_statuses }).
        where('policies.expiration_date < ?', Time.zone.now + 1.month).
        select('insurables.id').
        distinct.count
    end

    def supported_filters(called_from_orders = false)
      @calling_supported_orders = called_from_orders
      {
        id: %i[scalar array],
        title: %i[scalar like],
        permissions: %i[scalar array],
        insurable_type_id: %i[scalar array],
        insurable_id: %i[scalar array],
        agency_id: %i[scalar array],
        account_id: %i[scalar array],
        account: {
          title: %i[scalar like]
        }
      }
    end

    def supported_orders
      supported_filters(true)
    end
  end
end
