module Compliance
  module Audit
    module Concerns
      module LeasesEmailsMethods
        extend ActiveSupport::Concern

        include do

        def find_leases(created_at_search_range, start_date_search_range)
          puts "In find"
          @lease_ids = []
          master_policies = Policy.where(policy_type_id: 2, carrier_id: 2)
          master_policies.each do |master|
            master.insurables.communities.each do |community|
              #TODO: not the best option because seems that we do not update covered flags anymore for Lease & Insurable properly
              excluded_leases = Lease.joins(insurable: :policies).where(insurable_id: community.units.pluck(:id),
                                                                      created_at: created_at_search_range,
                                                                         policies: {
                                                                           policy_type_id: [PolicyType::RESIDENTIAL_ID, PolicyType::MASTER_COVERAGE_ID],
                                                                           status: %i[BOUND BOUND_WITH_WARNING EXTERNAL_VERIFIED]
                                                                         },
                                                                      start_date: start_date_search_range).pluck(:id)
              community_lease_ids = Lease.where(insurable_id: community.units.pluck(:id),
                                              created_at: created_at_search_range,
                                              start_date: start_date_search_range)
                                       .where.not(id: excluded_leases)
                                       .pluck(:id)
              @lease_ids = @lease_ids + community_lease_ids
            end
          end

          @leases = @lease_ids.blank? ? nil : Lease.find(@lease_ids)
        end
      end
    end
      end
end
end

