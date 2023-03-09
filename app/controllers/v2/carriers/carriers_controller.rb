# frozen_string_literal: true

module V2
  module Carriers
    class CarriersController < ApiController
      include ActionController::Caching

      CARRIERS_PER_PAGE = 50

      def index
        page = params[:page] || 1
        per_page = params[:per_page] || CARRIERS_PER_PAGE

        @carriers = ::Carrier.all.order(title: :asc).page(page).per(per_page)
        @meta = { total: @carriers.total_count, page: @carriers.current_page, per_page: per_page }

        render 'v2/carriers/index'
      end
    end
  end
end
