##
# V2 StaffAccount Dashboard Controller
# File: app/controllers/v2/staff_account/dashboard_controller.rb

module V2
  module StaffAccount
    class DashboardController < StaffAccountController
      # def total_dashboard
      #   unit_ids = InsurableType::UNITS_IDS
      #   @covered = Insurable.where(insurable_type_id: unit_ids, covered: true, account: current_staff.organizable).count || 0
      #   @uncovered = Insurable.where(insurable_type_id: unit_ids, covered: false, account: current_staff.organizable).count || 0
      #   @units = @covered + @uncovered
      #   community_ids = InsurableType::COMMUNITIES_IDS
      #   @communities = Insurable.where(insurable_type_id: community_ids, account: current_staff.organizable).count
      #   @total_policy = ::Policy.current.where(account: current_staff.organizable).count
      #   @total_residential_policies = ::Policy.current.where(policy_type_id: 1, account: current_staff.organizable).count
      #   @total_master_policies = ::Policy.current.where(policy_type_id: PolicyType::MASTER_IDS, account: current_staff.organizable).count
      #   @total_master_policy_coverages = ::Policy.current.where(policy_type_id: 3, account: current_staff.organizable).count
      #   @total_commercial_policies = ::Policy.current.where(policy_type_id: 4, account: current_staff.organizable).count
      #   @total_rent_guarantee_policies = ::Policy.current.where(policy_type_id: 5, account: current_staff.organizable).count
      #   policy_ids = ::Policy.where(account: current_staff.organizable).pluck(:id)
      #   policy_quote_ids = ::PolicyQuote.includes(:policy_application).references(:policy_applications).where(status: 'accepted', policy_applications: { account_id: current_staff.organizable.id }).pluck(:id)
      #   @total_commission = ::Commission.where(recipient: current_staff.organizable).pluck(:total).inject(:+) || 0
      #   @total_premium = ::PolicyPremium.where(policy_quote_id: policy_quote_ids).or(::PolicyPremium.where(policy_id: policy_ids)).pluck(:total_premium).inject(:+) || 0
      #
      #   render json: {
      #     total_units: @units,
      #     total_covered_units: @covered,
      #     total_uncovered_units: @uncovered,
      #     total_communities: @communities,
      #     total_policies: @total_policy,
      #     total_residential_policies: @total_residential_policies,
      #     total_master_policies: @total_master_policies,
      #     total_master_policy_coverages: @total_master_policy_coverages,
      #     total_commercial_policies: @total_commercial_policies,
      #     total_rent_guarantee_policies: @total_rent_guarantee_policies,
      #     total_commission: @total_commission,
      #     total_premium: @total_premium
      #   }, status: :ok
      render json: {
        message: "Currently Unavailable: Under Construction"
      }, status: :ok
      end

      def communities_list
        community_ids = InsurableType::COMMUNITIES_IDS
        @communities = Insurable.where(account: current_staff.organizable, insurable_type_id: community_ids)
        render json: { communities: @communities }, status: :ok
      end

      def buildings_communities
        @unit_ids = InsurableType::UNITS_IDS
        @units = Insurable.where(insurable_type_id: @unit_ids, account: current_staff.organizable).pluck(:id)

        if params[:community_id].present?
          # Later need to add leases
          # units = Insurable.joins(:leases).where(insurable_type_id: params[:community_id].to_i, account: current_staff)
          units = Insurable.where(insurable_id: params[:community_id].to_i, account: current_staff.organizable)
          @units_policies = paginator(Policy.joins(:insurables).where(insurables: { id: units.pluck(:id) }).order(created_at: :desc))
          render :buildings_communities, status: :ok
        elsif params[:type] == 'expired'
          expiration = 30.days.from_now
          units = Insurable.where(account: current_staff.organizable).pluck(:id)
          @units_policies = paginator(Policy.where('policies.expiration_date < ?', expiration).joins(:insurables).where(insurables: { id: units }).order(created_at: :desc))
          render :buildings_communities, status: :ok
        elsif params[:type] == 'expired' && params[:community_id].present?
          expiration = 30.days.from_now
          units = Insurable.where(insurable_id: params[:community_id].to_i, insurable_type_id: @unit_ids, account: current_staff.organizable).pluck(:id)
          @units_policies = paginator(Policy.where('policies.expiration_date < ?', expiration).joins(:insurables).where(insurables: { id: units }).order(created_at: :desc))
          render :buildings_communities, status: :ok
        else
          # units = Insurable.where(insurable_type_id: @unit_ids, covered: false).order(created_at: :desc)
          @units_policies = paginator(Policy.joins(:insurables).where(insurables: { id: @units }).order(created_at: :desc))
          render :buildings_communities, status: :ok
        end
      end

      def uninsured_units
        units_relation =
          Insurable.
            where(insurable_type_id: InsurableType::UNITS_IDS, covered: false, account: current_staff.organizable)

        units_relation = units_relation.where(insurable_id: params[:insurable_id]) if params[:insurable_id].present?
        @insurables = paginator(units_relation)
        render template: 'v2/shared/insurables/index', status: :ok
      end

      private

      def view_path
        super + '/dashboard'
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          id: %i[scalar array],
          title: %i[scalar like],
          permissions: %i[scalar array],
          insurable_type_id: %i[scalar array],
          insurable_id: %i[scalar array],
          account_id: %i[scalar array]
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end # module StaffAccount
end
