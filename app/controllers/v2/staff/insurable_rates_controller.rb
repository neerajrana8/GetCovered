# frozen_string_literal: true

module V2
  module Staff
    class InsurableRatesController < StaffController
      before_action :only_super_admins
      before_action :set_insurable_rate, only: %i[show update destroy]

      def index
        @insurable_rates = InsurableRate.all
      end

      def show; end

      def create
        @insurable_rate = InsurableRate.new(insurable_rate_params)

        if @insurable_rate.save
          render :show, status: :created, location: @insurable_rate
        else
          render json: @insurable_rate.errors, status: :unprocessable_entity
        end
      end

      def update
        if @insurable_rate.update(insurable_rate_params)
          render :show, status: :ok, location: @insurable_rate
        else
          render json: @insurable_rate.errors, status: :unprocessable_entity
        end
      end

      def destroy
        @insurable_rate.destroy
      end

      private

      def set_insurable_rate
        @insurable_rate = InsurableRate.find(params[:id])
      end

      def insurable_rate_params
        params.require(:insurable_rate).permit(
          :title, :schedule, :sub_schedule, :description, :liability_only,
          :number_insured, :interval, :premium, :activated, :activated_on,
          :deactivated_on, :paid_in_full, :carrier_id, :agency_id, :insurable_id
        )
      end
    end
  end
end
