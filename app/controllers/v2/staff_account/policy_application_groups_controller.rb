module V2
  module StaffAccount
    class PolicyApplicationGroupsController < StaffAccountController
      def upload_xlsx
        if params[:source_file].present?
          file = params[:source_file].open
          parsed_file = ::PolicyApplicationGroups::SourceXlsxParser.run!(xlsx_file: file)
          render json: { parsed_data: parsed_file }, status: 200
        else
          render json: { error: 'Need source_file' }, status: :unprocessable_entity
        end
      end

      def create
        policy_application_group = PolicyApplicationGroup.create

        errors = []

        policy_applications_params.each do |policy_application_params|
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
          render json: { success: false, errors: errors },
                 status: :unprocessable_entity
        else
          render json: policy_application_group.to_json, status: :ok
        end
      end

      private

      def common_params
        params.
          require(:policy_application_group).
          require(:common_attributes).
          permit(:effective_date, :expiration_date, :auto_pay,
                 :auto_renew, :account_id, :policy_type_id,
                 :carrier_id, :agency_id)
      end

      def policy_applications_params
        params.
          require(:policy_application_group).
          permit(
            policy_applications: [
              policy_application: [ :fields, :billing_strategy_id, fields: {}],
              policy_users: [
                :primary, :spouse, user_attributes: [
                  :email, profile_attributes: [
                    :first_name, :last_name, :job_title,
                    :contact_phone, :birth_date, :gender,
                    :salutation
                  ]
                ]
              ]
            ]
          ).
          require(:policy_applications)
      end
    end
  end
end
