module V2
  module StaffAgency
    class LeadsDashboardController < StaffAgencyController
      include Leads::LeadsDashboardCalculations
      include Leads::LeadsDashboardMethods

      before_action :set_substrate, only: :index
      check_privileges 'dashboard.leads'


      def set_substrate
        super
        @substrate = access_model(::Lead).presented.not_archived.includes(:profile, :tracking_url) if @substrate.nil?
      end
    end
  end
end
