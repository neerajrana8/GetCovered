# require 'lib/klaviyo/redis_client'

module V2
  module Public
    class LeadEventsController < PublicController
      include ::Leads::CreateMethods

      before_action :set_lead, only: :create

      def create
        if @lead.errors.any?
          render json: standard_error(:lead_creation_error, nil, @lead.errors.full_messages)
        else
          create_lead_event
          render template: 'v2/shared/leads/full'
        end
      end
    end
  end
end
