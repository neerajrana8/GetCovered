module V2
  module StaffSuperAdmin
    class ContactRecordsController < StaffSuperAdminController
      before_action :set_contact_record, only: [:show]
      def index
        @mail_records = paginator(ContactRecord.all.order("created_at DESC"))
      end

      def show
      end


      def gmail_sync
        GmailMailSyncJob.perform_later
        render json: {
          status: "Started Job"
        }
      end

      private

      def set_contact_record
        @contact_record = ContactRecord.find(params[:id])
      end
    end
  end

end
