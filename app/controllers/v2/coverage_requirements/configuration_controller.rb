module V2
  module CoverageRequirements
    # Coverage Requirements Configuration Endpoint
    class ConfigurationController < ApiController
      before_action :check_permissions

      def index

      end

      def show
        if (params[:insurable_id].present? or params[:account_id].present?)
          insurable = Insurable.find(params[:insurable_id]) if params[:insurable_id].present?
          account = Account.find(params[:account_id]) if params[:account_id].present?
          account = insurable.account unless params[:account_id].present?

          fr = {}

          if account
            account_requirements = account.coverage_requirements

            account_requirements.each do |ar|
              fr[ar.designation] = ar.id
            end
          end

          if params[:insurable_id].present?
            insurable_requirements = insurable.coverage_requirements
            insurable_requirements.each do |ir|
              fr[ir.designation] = ir.id
            end
          end

          coverage_requirements = CoverageRequirement.where(id: fr.values)

          resp = { data: coverage_requirements }
          status = 200
        else
          resp = { error: :not_enough_params }
          status = 400
        end
        render json: resp, status: status
      end

      # def create
      #   required = [:insurable_id, :account_id, :start_date]

      #   if required.all? { |k| params.has_key? k }
      #     insurable = Insurable.find(params[:insurable_id]) if params[:insurable_id].present?
      #     account = Account.find(params[:account_id]) if params[:account_id].present?

      #     coverage_requirements = CoverageRequirement.find_or_create_by(
      #       insurable_id: params[:insurable_id],
      #       account_id: params[:account_id],
      #       start_date: params[:start_date],
      #       designation: params[:designation],
      #       amount: params[:amount]
      #     )
      #     render json: { data: [ coverage_requirements ] }, status: :ok
      #   else
      #     render json: {errors: [:not_enough_params] }, status: 400
      #   end
      # end

      def update
        data = []

        configuration_params[:data].each do |item|
          if item[:id]
            r = CoverageRequirement.find(item[:id])
            r.designation = item[:designation]
            r.amount = item[:amount]
            r.start_date = item[:start_date]
            r.save
            data << r
          else
            if item[:insurable_id].present?
              cr = CoverageRequirement.find_by(
                  designation: item[:designation],
                  start_date: item[:start_date],
                  insurable_id: item[:insurable_id]
              )
            end

            unless item[:account_id].nil?
              account = Account.find(item[:account_id])
              cr = CoverageRequirement.find_by(
                  designation: item[:designation],
                  start_date: item[:start_date],
                  account_id: item[:account_id]
              )

              # Remove all settled requirements for insurable for this designation
              # when editing it for account_id

              CoverageRequirement.where(
                designation: item[:designation],
                start_date: item[:start_date],
                insurable_id: account.insurables.pluck(:id)
              ).update_all(amount: item[:amount])
            end

            if cr
              cr.amount = item[:amount]
              cr.save
            else
              cr = CoverageRequirement.create(item)
            end
            data << cr
          end
        end
        render json: { data: data }
      end

      def delete
        r = CoverageRequirement.find(params[:id])
        if r[:account_id]
          CoverageRequirement.where(
            designation: r[:designation],
            start_date: r[:start_date],
            insurable_id: r.account.insurables.pluck(:id)
          ).delete_all
        end
        CoverageRequirement.destroy(params[:id])
        render json: {message: "Record #{params[:id]} deleted" }, status: :ok
      end

      private

      def configuration_params
        params.permit(:data => [:id, :designation, :amount, :insurable_id, :account_id, :start_date])
      end


      def check_permissions
        if current_staff && %(super_admin, staff, agent).include?(current_staff.role)
          true
        else
          render json: { error: 'Permission denied' }, status: 403
        end
      end

    end
  end
end
