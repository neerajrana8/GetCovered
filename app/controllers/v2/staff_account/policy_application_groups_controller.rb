module V2
  module StaffAccount
    # This controller is used to the bulk policy creation
    class PolicyApplicationGroupsController < StaffAccountController
      before_action :set_policy_application_group, only: %i[show update accept destroy]
      before_action :parse_input_file, only: %i[create]
      before_action :validate_accept, only: %i[accept]

      def index
        groups_query = ::PolicyApplicationGroup.order(created_at: :desc).where(account: current_staff&.organizable)

        @policy_application_groups = paginator(groups_query)

        render template: 'v2/shared/policy_application_groups/index.json.jbuilder', status: :ok
      end

      def create
        @policy_application_group = ::PolicyApplicationGroup.create(policy_application_group_params)

        @parsed_input_file.each do |policy_application_params|
          all_policy_application_params =
            policy_application_params[:policy_application]
              .merge(common_params)
              .merge(policy_application_group: @policy_application_group)

          ::PolicyApplications::RentGuaranteeCreateJob.perform_later(
            all_policy_application_params,
            policy_application_params[:policy_users]
          )
        end

        render template: 'v2/shared/policy_application_groups/show.json.jbuilder', status: :ok
      end

      def update
        if edit_allowed?
          ap common_params
          ActiveRecord::Base.transaction do
            @policy_application_group.update(common_params)
            @policy_application_group.policy_applications.update_all(common_params.to_h)
            @policy_application_group.policy_group_quote&.generate_invoices_for_term(false, true)
          end
          render template: 'v2/shared/policy_application_groups/show.json.jbuilder', status: :ok
        else
          render json: { success: false, errors: ['The policy application is in the wrong state'] },
                 status: :unprocessable_entity
        end
      end

      def show
        render template: 'v2/shared/policy_application_groups/show.json.jbuilder', status: :ok
      end

      def accept
        if @policy_application_group.account.payment_profiles.where(default: true).take&.source_id
          result = @policy_application_group.policy_group_quote.accept

          if result[:success]
            render json: { success: true, message: result[:message] }, status: :ok
          else
            render json: { success: false, message: result[:message] }, status: :internal_server_error
          end
        else
          render json: {
            success: false,
            message: "Account doesn't have attached payment sources"
          }, status: :unprocessable_entity
        end
      end

      def destroy
        if destroy_allowed?
          result = ::PolicyApplicationGroups::TotalDestroy.run(policy_application_group: @policy_application_group)
          if result.valid?
            render json: { success: true }, status: :ok
          else
            render json: { success: false, messages: result.errors.messages }, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['The policy application is in the wrong state'] },
                 status: :unprocessable_entity
        end
      end

      private

      def validate_accept
        if @policy_application_group.effective_date < Time.zone.now &&
          @policy_application_group.policy_applications.where('effective_date < ?', Time.zone.now).any?
          render json: { error: 'Incorrect effective dates' }, status: :unprocessable_entity
        end
      end

      def policy_application_group_params
        billing_strategy =
          BillingStrategy.where(
            agency: current_staff&.organizable&.agency,
            policy_type: PolicyType.find_by_slug('rent-guarantee')
          ).take
        {
          policy_applications_count: @parsed_input_file.count,
          account: current_staff&.organizable,
          agency: current_staff&.organizable&.agency,
          policy_group_quote: ::PolicyGroupQuote.create(status: :awaiting_estimate),
          policy_type: PolicyType.find(5),
          carrier: Carrier.find_by_call_sign('P'),
          auto_renew: false,
          auto_pay: false,
          billing_strategy: billing_strategy
        }.merge(common_params)
      end

      def edit_allowed?
        %w[awaiting_acceptance].include?(@policy_application_group.status)
      end

      def destroy_allowed?
        %w[error awaiting_acceptance].include?(@policy_application_group.status)
      end

      def set_policy_application_group
        @policy_application_group = ::PolicyApplicationGroup.find(params[:id])
      end

      def parse_input_file
        if params[:input_file].present? &&
           params[:input_file].content_type == 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          file = params[:input_file].open
          result = ::PolicyApplicationGroups::SourceXlsxParser.run(xlsx_file: file)

          unless result.valid?
            render(json: { error: 'Bad file', content: result.errors[:bad_rows] }, status: :unprocessable_entity) && return
          end

          render json: { error: 'No valid rows' }, status: :unprocessable_entity if result.result.empty?

          @parsed_input_file = result.result
        else
          render json: { error: 'Need the correct xlsx spreadsheet' }, status: :unprocessable_entity
        end
      end

      def common_params
        params
          .require(:policy_application_group)
          .require(:common_attributes)
          .permit(:effective_date, :expiration_date, :auto_pay, :auto_renew)
      end
    end
  end
end
