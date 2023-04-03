module V2
  module Reports
    class ChargePushReportsController < ApiController
      before_action :check_permissions
      before_action :set_report, only: %i[show]

      def create
        account = Account.where(id: report_params[:account_id]).first
        community = Insurable.communities.where(id: report_params[:community_id]).first

        error_message =
          if report_params[:month].nil? || report_params[:year].nil?
            'Missing one of the following required parameters: month, year'
          elsif report_params[:account_id] && account.nil?
            'Account with provided ID does not exist'
          elsif report_params[:community_id] && community.nil?
            'Community with provided ID does not exist'
          end

        if error_message
          return render json: { error: error_message }, status: 422
        end

        date = DateTime.new(params[:year].to_i, params[:month].to_i, 1)

        report = ::Reports::ChargePushReport.new(
          reportable: account,
          reportable2: community,
          range_start: date,
          range_end: date.end_of_month
        )

        report.save

        render json: { id: report.id, created_at: report.created_at }, status: 201
      end

      def show
        @report.generate.save unless @report.data['rows']&.any?

        send_data @report.to_csv, filename: file_name('csv')
      end

      private

      def file_name(extension)
        "#{@report.type.underscore.split('/').last}-#{@report.created_at || Date.today}.#{extension}"
      end

      def set_report
        @report ||= Report.find(params[:id])
      end

      def check_permissions
        if current_staff && %w(super_admin staff agent).include?(current_staff.role)
          true
        else
          return render json: { error: 'Permission denied' }, status: 403
        end
      end

      def report_params
        params.permit(:month, :year, :account_id, :community_id)
      end
    end
  end
end
