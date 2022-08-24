module V2
  module StaffSuperAdmin
    class ContactRecordsController < StaffSuperAdminController
      before_action :set_contact_record, only: [:show]
      def index
        @mail_records = paginator(::ContactRecord.all)
      end

      def show
        if @contact_record.contactable_type === "User"
          @user = User.find(@contact_record.contactable_id)
        elsif @contact_record.contactable_type === "Staff"
          @user = Staff.find(@contact_record.contactable_id)
        end
      end


      def gmail_sync
        GmailMailSyncJob.perform_now
      end

      private

      def set_contact_record
        @contact_record = ContactRecord.find(params[:id])
      end
    end
  end

end
