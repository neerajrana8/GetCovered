# frozen_string_literal: true

module V2
  module Carriers
    class CarriersController < ApiController
      include ActionController::Caching

      CARRIERS_PER_PAGE = 50

      before_action :check_permissions, only: %i[index]

      def index
        page = params[:page] || 1
        per_page = params[:per_page] || CARRIERS_PER_PAGE

        @carriers = ::Carrier.all.order(created_at: :desc).page(page).per(per_page)
        @meta = { total: @carriers.total_count, page: @carriers.current_page, per_page: per_page }

        render 'v2/carriers/index'
      end

      private

      def check_permissions
        if current_staff && %w[super_admin staff agent].include?(current_staff.role)
          true
        else
          render json: { error: 'Permission denied' }, status: :forbidden
        end
      end
    end
  end
end
