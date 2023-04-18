module Compliance
  module Audit
    module Concerns
      module LeasesEmailsMethods
        extend ActiveSupport::Concern

        def find_leases(created_at_search_range, start_date_search_range)
          @lease_ids = []
          master_policies = Policy.includes(:insurables).where(policy_type_id: 2, carrier_id: 2)
          master_policies.each do |master|
            master.insurables.communities.each do |community|
              #TODO: not the best option because seems that we do not update covered flags anymore for Lease & Insurable properly
              unit_ids = community.units.confirmed.where(enabled: true)
              unit_ids = unit_ids.where.not(special_status: 'affordable') if master.account&.integrations&.where(provider: 'yardi')&.take&.configuration&.[]('sync')&.[]('special_status_mode').nil?
              unit_ids = unit_ids.pluck(:id)
              excluded_leases = Lease.joins(insurable: :policies).where(insurable_id: unit_ids,
                                                                        created_at: created_at_search_range,
                                                                        defunct: false,
                                                                        policies: {
                                                                          policy_type_id: [PolicyType::RESIDENTIAL_ID, PolicyType::MASTER_COVERAGE_ID],
                                                                          status: %i[BOUND BOUND_WITH_WARNING EXTERNAL_VERIFIED WITHOUT_STATUS]
                                                                        },
                                                                        start_date: start_date_search_range).select(:id)

              community_lease_ids = Lease.where(status: %w[current pending],
                                                insurable_id: unit_ids,
                                                created_at: created_at_search_range,
                                                start_date: start_date_search_range)
                                         .where.not(defunct: true)
                                         .where.not(special_status: 'affordable')
                                         .where.not(id: excluded_leases).pluck(:id)

              @lease_ids = @lease_ids + community_lease_ids
            end
          end

          @leases = @lease_ids.blank? ? nil : Lease.find(@lease_ids)
        end

      end
    end

  end
end
