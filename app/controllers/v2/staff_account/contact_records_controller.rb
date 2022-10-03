module V2
  module StaffAccount
    class ContactRecordsController < StaffAccountController
      before_action :set_contact_record, only: [:show]
      def index
        @account_users = @account.users + @account.staffs
        @mail_records = paginator(ContactRecord.where(contactable: @account_users).order("created_at DESC"))
      end

      def show
      end

      def user_mails
        if params[:contactable_type] === "User"
          user = ::User.find(params[:contactable_id])
        elsif params[:contactable_type] === "Staff"
          user = ::Staff.find(params[:contactable_id])
        end
        @mail_records = paginator(ContactRecord.where(contactable: user).order("created_at DESC"))
      end



      private

      def set_contact_record
        @contact_record = ContactRecord.find(params[:id])
      end
    end
  end

end
