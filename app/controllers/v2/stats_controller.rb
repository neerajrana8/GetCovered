module V2
  class StatsController < DefaultController
    prepend Gc
    skip_before_action :verify_authenticity_token
    before_action :stats

    layout 'gc_tool'

    def show
      @stats = {

        insurables_total: all_insurables.count,
        units_total: all_units.count,
        units_covered: all_covered_units.count,
        units_uncovered: all_uncovered_units.count,
        units_with_valid_lease: all_units_with_valid_lease.count,
        units_with_expired_lease: all_units_with_expired_lease.count,
        units_without_any_lease: all_units_without_any_lease.count,
        leases_total: all_leases.count,
        all_covered_leases_with_valid_date: all_covered_leases_with_valid_date.count,
        all_uncovered_leases_with_valid_date: all_uncovered_leases_with_valid_date.count,
        policies_total: all_policices.count,
        policies_valid_by_date: all_valid_by_date_policies.count,
        policies_valid_by_status: active_policies.count,
        policies_valid_by_status_and_date: policies_valid_by_status_and_date.count

      }
      render :show, formats: :html
    end

    def policy
      @policy = Policy.find(params[:policy_id]) if params[:policy_id]

      if @policy
        @insurable = policy_insurable(@policy)
        @leases = insurable_leases(@insurable)
      end

      render :policy, formats: :html
    end

    def update
      if params[:policy_id]

        policy = Policy.find(params[:policy_id])

        @tenants_mismatched_cx = 0
        # Unit
        insurable = policy_insurable(policy)
        check_date = DateTime.now
        # next unless insurable
        @leases = []
        insurable_leases(insurable).each do |lease|
          # Check tenants is matching
          unless tenant_matched?(lease, policy)
            @tenants_mismatched_cx += 1
            next
          end

          if lease_shouldbe_covered?(policy, lease, check_date)
            cover_lease(lease)
            make_lease_current(lease)
          else
            uncover_lease(lease)
            make_lease_expired(lease) if lease_expired?(lease, check_date)
          end

          @leases << lease
        end


        unit = insurable
        unit_policies(unit).each do |po|
          # next unless tenant_matched?(lease, policy)

          if policy_shouldbe_expired?(po, check_date)
            uncover_unit(unit)
            make_policy_expired_status(po)
          end

          lease = active_lease(unit)
          if unit_shouldbe_covered?(lease, po, check_date)
            cover_unit(unit)
          else
            uncover_unit(unit)
          end

          if policy_expired_status?(po)
            uncover_unit(unit)
          else
            cover_unit(unit)
          end
        end


        @policy = policy.reload
        @insurable = insurable
      end
      render :update, formats: :html
    end

    def stats
      @resp = with_captured_stdout { stats_as_table }
    end
  end
end
