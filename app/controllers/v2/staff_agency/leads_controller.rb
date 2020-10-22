module V2
  module StaffAgency
    class LeadsController < StaffAgencyController

      before_action :set_substrate, only: :index

      def index
        super(:@leads, @substrate)
        render 'v2/shared/leads/index'
      end

      def show
        @lead = access_model(::Lead, params[:id])
        render 'v2/shared/leads/show'
      end

      private

      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::Lead).includes(:profile, :tracking_url)
        end
      end
    end
  end
end
