# frozen_string_literal: true

module V2
  module Carriers
    class CarriersController < ApiController
      include ActionController::Caching

      before_action :check_permissions, only: %i[merge]
      before_action :set_carrier, only: %i[merge]

      CARRIERS_PER_PAGE = 50

      def index
        page = params[:page] || 1
        per_page = params[:per_page] || CARRIERS_PER_PAGE

        @carriers = ::Carrier.all.order(title: :asc).page(page).per(per_page)
        @meta = { total: @carriers.total_count, page: @carriers.current_page, per_page: per_page }

        render 'v2/carriers/index'
      end

      def merge
        carriers_to_merge = Carrier.where(id: params[:carriers_to_merge_ids])

        begin
          @carrier = CarriersMerger.new(@set_carrier, carriers_to_merge).call
        rescue StandardError => e
          return render json: { error: e }, status: 400
        end

        render 'v2/shared/carriers/show'
      end

      private

      def set_carrier
        @set_carrier ||= Carrier.find(params[:id])
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
