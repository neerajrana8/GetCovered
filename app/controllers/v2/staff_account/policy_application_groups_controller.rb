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
        @application_group = PolicyApplicationGroup.create
        @agency =
          if current_staff.organizable.is_a?(Agency)
            current_staff.organizable
          elsif current_staff.organizable.is_a?(Account)
            current_staff.organizable.agency
          end
        policy_applications_params.each do

        end
        if @application.save
          if create_policy_users()
            if @application.update status: "complete"

              # if application.status updated to complete
              @application.qbe_estimate()
              @quote = @application.policy_quotes.last
              if @application.status != "quote_failed" || @application.status != "quoted"
                # if application quote success or failure
                @application.qbe_quote(@quote.id)
                @application.reload()
                @quote.reload()

                if @quote.status == "quoted"

                  @application.primary_user().set_stripe_id()

                  render json: {
                    id: @application.id,
                    quote: {
                      id: @quote.id,
                      status: @quote.status,
                      premium: @quote.policy_premium
                    },
                    invoices: @quote.invoices.order('due_date ASC'),
                    user: {
                      id: @application.primary_user().id,
                      stripe_id: @application.primary_user().stripe_id
                    }
                  }.to_json, status: 200

                else
                  render json: { error: "Quote Failed", message: "Quote could not be processed at this time" },
                         status: 500
                end
              else
                render json: { error: "Application Unavailable", message: "Application cannot be quoted at this time" },
                       status: 400
              end

            else
              render json: @application.errors.to_json,
                     status: 422
            end
          end
        else
          render json: @application.errors.to_json,
                 status: 422
        end
      end

      private

      def create_permitted_params
        params.require(:policy_application_group)
          .permit(:effective_date, :expiration_date, :fields, :auto_pay,
                  :auto_renew, :billing_strategy_id, :account_id, :policy_type_id,
                  :carrier_id, :agency_id, fields: {})
      end
    end
  end
end
