module Reports
  class ConfieReportJob < ApplicationJob
    queue_as :default
    before_perform :set_policy_applications

    def perform(*_args)
      cs = ConfieService.new
      @policy_applications.each do |pa|
        next if pa.tagging_data.nil? || pa.tagging_data['confie_mediacode'].nil? ||
                !pa.tagging_data['confie_external'] || pa.tagging_data['confie_reported']
        if cs.build_request(:update_lead,
          id: pa.id.to_s,
          status: pa.status,
          mediacode: pa.tagging_data['confie_mediacode'],
          line_breaks: true
        )
          event = pa.events.new(cs.event_params)
          event.started = Time.now
          result = cs.call
          event.completed = Time.now
          event.request = result[:response].request.raw_body
          event.response = result[:response].response.body
          event.status = result[:error] ? 'error' : 'success'
          event.save
          pa.update_columns(tagging_data: pa.tagging_data.merge({'confie_reported' => true}))
        end
      end
    end

    private

      def set_policy_applications
        current_time = Time.current.beginning_of_hour
        confie_id = ConfieService.agency_id
        @policy_applications = confie_id.nil? ? [] : ::PolicyApplication.where(
          agency_id: confie_id,
          created_at: (current_time - 1.hour)...(current_time)
        )#.where.not(status: ['accepted']) # DISABLED since we go ahead and inform them of sold ones too
      end
  end
end
