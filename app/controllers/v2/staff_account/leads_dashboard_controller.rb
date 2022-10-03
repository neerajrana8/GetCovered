module V2
  module StaffAccount
    class LeadsDashboardController < StaffAccountController
      include Concerns::Leads::LeadsDashboardCalculations
      include Concerns::Leads::LeadsDashboardMethods

      before_action :set_substrate, only: :index

      def set_substrate
        super
        @substrate = access_model(::Lead).presented.not_archived.includes(:profile, :tracking_url) if @substrate.nil?
      end
    end
  end
end
