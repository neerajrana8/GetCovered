module Reports
  class ConfieReportJob < ApplicationJob
    queue_as :default
    before_perform :set_policy_applications

    def perform(*_args)
      # do something with @policy_applications
    end

    private
    
      def set_policy_applications
        current_time = Time.current.beginning_of_hour
        @policy_applications = ::PolicyApplication.where(agency_id: ConfieService.agency_id)
                                                  .where.not(status: ['complete']) # MOOSE WARNING: expand?
                                                  .where(created_at: (current_time - 1.hour)...(current_time))
      end
  end
end
