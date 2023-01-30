module V2
  class StatsController < DefaultController
    prepend Gc
    skip_before_action :verify_authenticity_token
    before_action :stats

    layout 'gc_tool'


    def show

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
       unit_policies(unit).each do |policy|
         # next unless tenant_matched?(lease, policy)

         if policy_shouldbe_expired?(policy, check_date)
           uncover_unit(unit)
           make_policy_expired_status(policy)
         end

         lease = active_lease(unit)
         if unit_shouldbe_covered?(lease, policy, check_date)
           cover_unit(unit)
         end

         if policy_expired_status?(policy)
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
