##
# V2 StaffSuperAdmin Dashboard Controller
# File: app/controllers/v2/staff_super_admin/dashboard_controller.rb

module V2
  module StaffSuperAdmin
    class DashboardController < StaffSuperAdminController
      include DashboardMethods

      def total_dashboard
        # @covered = Insurable.where(covered: true).count || 0
        # @uncovered = Insurable.where(covered: false).count || 0
        # @units = @covered + @uncovered
        # community_ids = InsurableType::COMMUNITIES_IDS
        # @communities = Insurable.where(insurable_type_id: community_ids).count
        # @total_policy = ::Policy.current.pluck(:id).count
        # @total_residential_policies = ::Policy.current.where(policy_type_id: 1).count
        # @total_master_policies = ::Policy.current.where(policy_type_id: PolicyType::MASTER_IDS).count
        # @total_master_policy_coverages = ::Policy.current.where(policy_type_id: 3).count
        # @total_commercial_policies = ::Policy.current.where(policy_type_id: 4).count
        # @total_rent_guarantee_policies = ::Policy.current.where(policy_type_id: 5).count
        # policy_ids = ::Policy.pluck(:id)
        # @total_commission = ::Commission.where(recipient_type: 'Agency', recipient_id: 1).pluck(:total).inject(:+) || 0  # this is total GetCovered commissions
        # @total_premium = ::PolicyPremium.where(policy_quote_id: ::PolicyQuote.where(status: 'accepted').pluck(:id)).or(::PolicyPremium.where(policy_id: policy_ids)).pluck(:total_premium).inject(:+) || 0
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
        @communities = Insurable.where(insurable_type_id: community_ids)
        render json: { communities: @communities }, status: :ok
      end

      def buildings_communities
        @unit_ids = InsurableType::UNITS_IDS
        @units = Insurable.where(insurable_type_id: @unit_ids).pluck(:id)

        if params[:community_id].present?
          # units = Insurable.joins(:leases).where(insurable_type_id: params[:community_id].to_i, agency_id: @current_agency)
          units = Insurable.where(insurable_id: params[:community_id].to_i).pluck(:id)
          @units_policies = paginator(Policy.joins(:insurables).where(insurables: { id: units }).order(created_at: :desc))
          render :buildings_communities, status: :ok
        elsif params[:type] == 'expired'
          expiration = 30.days.from_now
          # @units_policies = paginator(Policy.where('expiration_date < ?', expiration).joins(:insurables).where(insurables: { id: @units, covered: true }).order(created_at: :desc))
          @units_policies = paginator(Policy.where('expiration_date < ?', expiration).joins(:insurables).where(insurables: { id: @units }).order(created_at: :desc))
          render :buildings_communities, status: :ok
        elsif params[:type] == 'expired' && params[:community_id].present?
          expiration = 30.days.from_now
          units = Insurable.where(insurable_id: params[:community_id].to_i, insurable_type_id: @unit_ids).pluck(:id)
          @units_policies = paginator(Policy.where('expiration_date < ?', expiration).joins(:insurables).where(insurables: { id: units }).order(created_at: :desc))
          render :buildings_communities, status: :ok
        else
          # units = Insurable.joins(:leases).where(insurable_type_id: @unit_ids, covered: false, agency_id: @current_agency).order(created_at: :desc)
          @units_policies = paginator(Policy.joins(:insurables).where(insurables: { id: @units }).order(created_at: :desc))
          render :buildings_communities, status: :ok
        end
      end

      def uninsured_units
        units_relation = Insurable.where(insurable_type_id: InsurableType::UNITS_IDS, covered: false)
        units_relation = units_relation.where(insurable_id: params[:insurable_id]) if params[:insurable_id].present?
        @insurables = paginator(units_relation)

        render template: 'v2/shared/insurables/index', status: :ok
      end

      def reports
        # min = params[:start]
        # max = params[:end]
        # type = params[:type]
        # report = Report.joins('LEFT JOIN reports r2 ON (date(reports.created_at) = date(r2.created_at) AND reports.id < r2.id)')
        #   .where('r2.id IS NULL').where(reportable_type: 'Agency')
        #
        # # reports = Agency.where(created_at: min..max).map { |report| report.coverage_report }
        # # report = Report.where(created_at: min..max, reportable_type: 'Agency', type: type).group('created_at', 'id')
        # # reports = report.joins("LEFT JOIN reports r2 ON (date(reports.created_at) = date(r2.created_at) AND reports.id < r2.id)")
        # #                 .where("r2.id IS NULL")
        # reports = report.where(type: type, created_at: min..max).to_a
        # render json: reports, status: :ok
        render json: {
          message: "Currently Unavailable: Under Construction"
        }, status: :ok
      end

      private

      def view_path
        super + '/dashboard'
      end

      def communities
        Insurable.where(insurable_type_id: InsurableType::COMMUNITIES_IDS)
      end
    end
  end # module StaffSuperAdmin
end
