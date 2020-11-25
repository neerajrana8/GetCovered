module Reports
  class ConfieReportJob < ApplicationJob
    queue_as :default
    before_perform :set_policy_applications

    def perform(*_args)
      # do something with @policy_applications
      cs = ConfieService.new
      @policy_applications.each do |pa|
        next if pa.tagging_data.nil? || pa.tagging_data['confie_mediacode'].nil?
        if cs.build_request(:online_policy_sale,
          id: pa.id,
          status: pa.status,
          mediacode: pa.tagging_data['confie_mediacode']
          line_breaks: true
        )
          event = pa.events.new(cs.event_params)
          event.started = Time.now
          result = cs.call
          event.completed = Time.now
          event.response = result[:response].response.body
          event.status = result[:error] ? 'error' : 'success'
          event.save
        end
      end
    end

    private
    
      def set_policy_applications
        current_time = Time.current.beginning_of_hour
        confie_id = ConfieService.agency_id
        @policy_applications = confie_id.nil? ? [] : ::PolicyApplication.where(agency_id: confie_id)
                                                  .where(created_at: (current_time - 1.hour)...(current_time))
                                                  #.where.not(status: ['accepted'])
      end
  end
end
