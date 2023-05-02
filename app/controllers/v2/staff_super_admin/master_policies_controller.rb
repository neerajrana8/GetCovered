##
# V2 StaffAccount Master Policies Controller
# File: app/controllers/v2/staff_account/master_policies_controller.rb

module V2
  module StaffSuperAdmin
    class MasterPoliciesController < StaffSuperAdminController
      include MasterPoliciesMethods

      def index
        master_policies_relation = Policy.where(policy_type_id: PolicyType::MASTER_IDS).order(created_at: :desc)
        master_policies_relation = master_policies_relation.where(status: params[:status]) if params[:status].present?

        master_policies_relation = master_policies_relation.where("number LIKE ?", "%#{params[:number]}%") if params[:number].present?
        master_policies_relation = master_policies_relation.where(account_id: params[:account_id]) if params[:account_id].present?

        if params[:insurable_id].present?
          policy_insurables = PolicyInsurable.where(insurable_id: params[:insurable_id])
          unless policy_insurables.count.zero?
            master_policies_relation = master_policies_relation.where(id: policy_insurables.pluck(:policy_id))
          end
        end

        if params[:account_title].present?
          accounts = Account.where("title ILIKE ?", "%#{params[:account_title]}%")
          unless accounts.count.zero?
            master_policies_relation = master_policies_relation.where(account_id: accounts.pluck(:id))
          end
        end

        # NOTE: WTF ? Possible outdated logic legacy
        # if params[:insurable_id].present?
        #   insurable = Insurable.find(params[:insurable_id])

        #   current_types_ids = insurable.policies.current.pluck(:policy_type_id)
        #   master_policies_relation = master_policies_relation.where.not(policy_type_id: current_types_ids)
        # end

        # super(:@master_policies, master_policies_relation)
        @master_policies = paginator(master_policies_relation)
        render template: 'v2/shared/master_policies/index', status: :ok
      end

      def new
        @master_policy = Policy.new(
          effective_date: (Time.current + 1.months).at_beginning_of_month,
          policy_type_id: 2,
          carrier: Carrier.find(2)
        )
        @master_policy.qbe_master_build_coverage_options
        render @master_policy.as_json(include: :policy_coverages)
      end

      def upload_coverage_list
        logger.debug params.to_json
        render json: { success: true, message: "The owl flies tonight" }.to_json, status: :ok
        # @account = Account.find(params[:account_id])
        # @file = Utilities::S3Uploader.call(params[:file], build_upload_file_name(@account.slug),
        #                                  '/eois/qbe-specialty/master/', nil)
        # render json: { success: true, file_url: @file }.to_json, status: :ok
      end

      def set_policy
        @master_policy = Policy.find_by(policy_type_id: PolicyType::MASTER_IDS, id: params[:id])
        render(json: { error: :not_found, message: 'Master policy not found' }, status: :not_found) if @master_policy.blank?
      end

      private

      def upload_coverage_list_params
        params.require(:coverage_list).permit(:account_id, :tpp, :tpp_limit, :tpp_aggregate, :tpl, :tpl_limit,
                                              :tpl_aggregate, :file)
      end

      def build_upload_file_name(account_slug)
        [
          'master-list',
          account_slug,
          DateTime.current.strftime('%Y%m%d%H%M%S'),
          'csv'
        ].join('.')
      end
    end
  end
end
