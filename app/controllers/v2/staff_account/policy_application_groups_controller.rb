module V2
  module StaffAccount
    class PolicyApplicationGroupsController < StaffAccountController
      before_action :set_policy_application_group, only: %i[show destroy]
      before_action :parse_input_file, only: %i[create]

      def index
        groups_query = ::PolicyApplicationGroup.order(created_at: :desc).where(account: current_staff&.organizable)

        @policy_application_groups = paginator(groups_query)

        render template: 'v2/shared/policy_application_groups/index.json.jbuilder', status: :ok
      end

      def show
        render template: 'v2/shared/policy_application_groups/show.json.jbuilder', status: :ok
      end

      def create
        @policy_application_group = ::PolicyApplicationGroup.create(
          policy_applications_count: @parsed_input_file.count,
          account: current_staff&.organizable,
          agency: current_staff&.organizable&.agency,
          policy_group_quote: ::PolicyGroupQuote.create(status: :awaiting_estimate)
        )

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

      def accept_quote
        result = @policy_application_group.policy_group_quote.accept

        render json: {
          error: result[:success] ? 'Policy Group Accepted' : 'Policy Group Could Not Be Accepted',
          message: result[:message]
        }, status: result[:success] ? 200 : 500
      end

      def destroy
        if destroy_allowed?
          if @policy_application_group.destroy
            render json: { success: true }, status: :ok
          else
            render json: { success: false }, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unprocessable_entity
        end
      end

      private

      def destroy_allowed?
        true
      end

      def set_policy_application_group
        @policy_application_group = ::PolicyApplicationGroup.find(params[:id])
      end

      def parse_input_file
        if params[:input_file].present?
          file = params[:input_file].open
          result = ::PolicyApplicationGroups::SourceXlsxParser.run(xlsx_file: file)

          unless result.valid?
            render json: { error: 'Bad file', content: result.errors[:bad_rows] },
                   status: :unprocessable_entity
          end

          render json: { error: 'No rows' }, status: :unprocessable_entity if result.result.empty?

          @parsed_input_file = result.result
        else
          render json: { error: 'Need input_file' }, status: :unprocessable_entity
        end
      end

      def common_params
        params
          .require(:policy_application_group)
          .require(:common_attributes)
          .permit(:effective_date, :expiration_date, :auto_pay,
                  :auto_renew, :account_id, :agency_id)
      end
    end
  end
end
