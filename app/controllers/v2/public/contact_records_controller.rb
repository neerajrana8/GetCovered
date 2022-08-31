module V2
  module Public
    class ContactRecordsController < PublicController
      require 'sendgrid-ruby'
      include SendGrid
      def sendgrid_mails
        events_to_process = %w[processed delivered]
        sg = SendGrid::API.new(api_key: Rails.application.credentials.sendgrid[:development])
        params[:_json].each do |event|
          user = User.where(email: event['email'])
          if user.count > 0
          next unless events_to_process.include? event['event']
          next unless event['template_id'].present?
          response = sg.client.templates._(event['template_id']).get()
          body = JSON.parse response.body
          record_mail(user.last, body, event['event'])
          else
            logger.info event['email'] + 'user not fount'
          end
        end
        render json: {
          status: 'Processed'
        }
      end

      private

      def record_mail(user, body, event)
        contact_record = ContactRecord.new(
          approach: 'email',
          direction: 'Outgoing',
          status: event,
          contactable: user,
          body: body['versions'].last['plain_content'],
          source: 'sendgrid',
          thread_id: body['versions'].last['template_id'],
          subject: body['versions'].last['subject']
        )
        contact_record.save
      end
    end
  end
end
