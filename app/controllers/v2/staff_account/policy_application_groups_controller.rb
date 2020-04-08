module V2
  module StaffAccount
    class PolicyApplicationGroupsController < StaffAccountController
      before_action :parse_input_file, only: [:upload_xlsx, :create]

      def upload_xlsx
        render json: { parsed_data: @parsed_input_file }, status: 200
      end

      def create
        policy_application_group = PolicyApplicationGroup.create

        errors = []

        @parsed_input_file.each do |policy_application_params|
          all_policy_application_params =
            policy_application_params[:policy_application].
              merge(common_params).
              merge(policy_application_group: policy_application_group)

          outcome = ::PolicyApplications::RentGuarantee::Create.run(
            policy_application_params: all_policy_application_params,
            policy_users_params: policy_application_params[:policy_users]
          )

          unless outcome.valid?
            errors << {
              policy_application_params: all_policy_application_params,
              errors: outcome.errors.to_json
            }
          end
        end

        if errors.present?
          policy_application_group.delete
          render json: { success: false, errors: errors },
                 status: :unprocessable_entity
        else
          render json: policy_application_group.to_json, status: :ok
        end
      end

      private

      def parse_input_file
        if params[:input_file].present?
          file = params[:input_file].open
          @parsed_input_file = ::PolicyApplicationGroups::SourceXlsxParser.run!(xlsx_file: file)
        else
          render json: { error: 'Need input_file' }, status: :unprocessable_entity
        end
      end

      def common_params
        params.
          require(:policy_application_group).
          require(:common_attributes).
          permit(:effective_date, :expiration_date, :auto_pay,
                 :auto_renew, :account_id, :policy_type_id,
                 :carrier_id, :agency_id)
      end
    end
  end
end
