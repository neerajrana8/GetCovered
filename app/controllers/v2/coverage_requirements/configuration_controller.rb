module V2
  module CoverageRequirements
    class ConfigurationController < ApiController

      before_action :check_permissions

      def index

      end

      def show
        required = [:insurable_id, :account_id, :insurable_id]

        if required.all? { |k| params.key? k }
          insurable = Insurable.find(params[:insurable_id]) if params[:insurable_id].present?
          account = Account.find(params[:account_id]) if params[:account_id].present?

          coverage_requirements = CoverageRequirement.where(insurable_id: params[:insurable_id]) if params[:insurable_id].present?
          coverage_requirements = CoverageRequirement.where(account_id: params[:account_id]) if params[:account_id].present?

          render json: { data: coverage_requirements }
        else
          resp = { error: :not_enough_params }
          render json: resp , status: 400
        end
      end

      def create
        required = [:insurable_id, :account_id, :start_date]

        if required.all? { |k| params.has_key? k }
          insurable = Insurable.find(params[:insurable_id]) if params[:insurable_id].present?
          account = Account.find(params[:account_id]) if params[:account_id].present?

          coverage_requirements = CoverageRequirement.find_or_create_by(
            insurable_id: params[:insurable_id],
            account_id: params[:account_id],
            start_date: params[:start_date],
            designation: params[:designation],
            amount: params[:amount]
          )
          render json: { data: [ coverage_requirements ] }, status: :ok
        else
          render json: {errors: [:not_enough_params] }, status: 400
        end
      end

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
            cr = CoverageRequirement.find_by(
              {
                designation: item[:designation],
                start_date: item[:start_date]
              }
            )
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
