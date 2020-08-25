##
# V2 StaffAgency Dashboard Controller
# File: app/controllers/v2/staff_agency/dashboard_controller.rb

module V2
  module StaffAgency
    class DashboardController < StaffAgencyController
      before_action :set_staff_agency, only: [:communities_list, :buildings_communities]

      def total_dashboard
        unit_ids = InsurableType::UNITS_IDS
        community_ids = InsurableType::COMMUNITIES_IDS
        @covered = Insurable.where(covered: true).count || 0
        @uncovered = Insurable.where(covered: false).count || 0
        @units = @covered + @uncovered
        @communities = Insurable.where(insurable_type_id: community_ids).count
        @total_policy = ::Policy.count
        @total_residential_policies = ::Policy.where(policy_type_id: 1).count
        @total_master_policies = ::Policy.where(policy_type_id: 2).count
        @total_master_policy_coverages = ::Policy.where(policy_type_id: 3).count
        @total_commercial_policies = ::Policy.where(policy_type_id: 4).count
        @total_rent_guarantee_policies = ::Policy.where(policy_type_id: 5).count
        policy_ids = ::Policy.pluck(:id)
        @total_commission = PolicyPremium.where(id: policy_ids).pluck(:total).inject(:+) || 0
        @total_premium = PolicyPremium.where(id: policy_ids).pluck(:total_fees).inject(:+) || 0

        render json: {
          total_units: @units,
          total_covered_units: @covered,
          total_uncovered_units: @uncovered,
          total_communities: @communities,
          total_policies: @total_policy,
          total_residential_policies: @total_residential_policies,
          total_master_policies: @total_master_policies,
          total_master_policy_coverages: @total_master_policy_coverages,
          total_commercial_policies: @total_commercial_policies,
          total_rent_guarantee_policies: @total_rent_guarantee_policies,
          total_commission: @total_commission,
          total_premium: @total_premium
        }, status: :ok
      end

      def communities_list
        community_ids = InsurableType::COMMUNITIES_IDS
        @communities = Insurable.where(agency_id: @current_agency, insurable_type_id: community_ids)
        render json: { communities: @communities }, status: :ok
      end

      def buildings_communities
        @unit_ids = InsurableType::UNITS_IDS
        @units = Insurable.where(insurable_type_id: @unit_ids, agency_id: @current_agency).pluck(:id)

        if params[:community_id].present?
          # Later need to add leases
          # units = Insurable.joins(:leases).where(insurable_type_id: params[:community_id].to_i, agency_id: @current_agency)
          units = Insurable.where(insurable_id: params[:community_id].to_i, agency_id: @current_agency)
          @units_policies = paginator(Policy.joins(:insurables).where(insurables: { id: units.pluck(:id) }).order(created_at: :desc))
          render :buildings_communities, status: :ok
        elsif params[:type] == 'expired'
          expiration = 30.days.from_now
          @units_policies = paginator(Policy.where('expiration_date < ?', expiration).joins(:insurables).where(insurables: { id: @units }).order(created_at: :desc))
          render :buildings_communities, status: :ok
        elsif params[:type] == 'expired' && params[:community_id].present?
          expiration = 30.days.from_now
          units = Insurable.where(insurable_id: params[:community_id].to_i).pluck(:id)
          @units_policies = paginator(Policy.where('expiration_date < ?', expiration).joins(:insurables).where(insurables: { id: units }).order(created_at: :desc))
          render :buildings_communities, status: :ok
        else
          # Later need to add leases
          @units_policies = paginator(Policy.joins(:insurables).where(insurables: { id: @units }).order(created_at: :desc))
          render :buildings_communities, status: :ok
        end
      end

      private

      def view_path
        super + '/dashboard'
      end

      def set_staff_agency
        @current_agency = current_staff.organizable.id
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          id: %i[scalar array],
          title: %i[scalar like],
          permissions: %i[scalar array],
          insurable_type_id: %i[scalar array],
          insurable_id: %i[scalar array],
          agency_id: %i[scalar array]
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end # module StaffAgency
end
