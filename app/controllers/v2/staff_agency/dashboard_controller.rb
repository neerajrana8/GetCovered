##
# V2 StaffAgency Dashboard Controller
# File: app/controllers/v2/staff_agency/dashboard_controller.rb

module V2
  module StaffAgency
    class DashboardController < StaffAgencyController
      include DashboardMethods

      check_privileges 'dashboard.properties'

      def total_dashboard
        # unit_ids = InsurableType::UNITS_IDS
        # community_ids = InsurableType::COMMUNITIES_IDS
        # @covered = Insurable.where(insurable_type_id: unit_ids, covered: true, account: @agency.accounts).count
        # @uncovered = Insurable.where(insurable_type_id: unit_ids, covered: false, account: @agency.accounts).count
        # @units = @covered + @uncovered
        # @communities = Insurable.where(insurable_type_id: community_ids, account: @agency.accounts).count
        # @total_policy = ::Policy.current.where(agency: @agency).count
        # @total_residential_policies = ::Policy.current.where(policy_type_id: 1, agency: @agency).count
        # @total_master_policies = ::Policy.current.where(policy_type_id: PolicyType::MASTER_IDS, agency: @agency).count
        # @total_master_policy_coverages = ::Policy.current.where(policy_type_id: 3, agency: @agency).count
        # @total_commercial_policies = ::Policy.current.where(policy_type_id: 4, agency: @agency).count
        # @total_rent_guarantee_policies = ::Policy.current.where(policy_type_id: 5, agency: @agency).count
        # policy_ids = ::Policy.where(agency: @agency).pluck(:id)
        # policy_quote_ids = ::PolicyQuote.includes(:policy_application).references(:policy_applications).where(status: 'accepted', policy_applications: { agency_id: @agency.id }).pluck(:id)
        # @total_commission = ::Commission.where(recipient: @agency).pluck(:total).inject(:+) || 0
        # @total_premium = ::PolicyPremium.where(policy_quote_id: policy_quote_ids).or(::PolicyPremium.where(policy_id: policy_ids)).pluck(:total_premium).inject(:+) || 0
        #
        # render json: {
        #   total_units: @units,
        #   total_covered_units: @covered,
        #   total_uncovered_units: @uncovered,
        #   total_communities: @communities,
        #   total_policies: @total_policy,
        #   total_residential_policies: @total_residential_policies,
        #   total_master_policies: @total_master_policies,
        #   total_master_policy_coverages: @total_master_policy_coverages,
        #   total_commercial_policies: @total_commercial_policies,
        #   total_rent_guarantee_policies: @total_rent_guarantee_policies,
        #   total_commission: @total_commission,
        #   total_premium: @total_premium
        # }, status: :ok
        render json: {
          message: "Currently Unavailable: Under Construction"
        }, status: :ok
      end

      def communities_list
        community_ids = InsurableType::COMMUNITIES_IDS
        @communities = Insurable.where(account: @agency.accounts, insurable_type_id: community_ids)
        render json: { communities: @communities }, status: :ok
      end

      def buildings_communities
        @unit_ids = InsurableType::UNITS_IDS
        @units = Insurable.where(insurable_type_id: @unit_ids, account: @agency.accounts).pluck(:id)

        if params[:community_id].present?
          # Later need to add leases
          # units = Insurable.joins(:leases).where(insurable_type_id: params[:community_id].to_i, agency_id: @current_agency)
          units = Insurable.where(insurable_id: params[:community_id].to_i, account: @agency.accounts)
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

      def uninsured_units
        units_relation =
          Insurable.
            where(insurable_type_id: InsurableType::UNITS_IDS, covered: false, account: @agency.accounts)
        units_relation = units_relation.where(insurable_id: params[:insurable_id]) if params[:insurable_id].present?
        @insurables = paginator(units_relation)

        render template: 'v2/shared/insurables/index', status: :ok
      end

      private

      def view_path
        super + '/dashboard'
      end

      def communities
        accounts_communities =
          Insurable.where(insurable_type_id: InsurableType::COMMUNITIES_IDS, account: @agency.accounts)
        agency_communities =
          Insurable.where(insurable_type_id: InsurableType::COMMUNITIES_IDS, agency: @agency)
        accounts_communities.or agency_communities
      end
    end
  end # module StaffAgency
end
