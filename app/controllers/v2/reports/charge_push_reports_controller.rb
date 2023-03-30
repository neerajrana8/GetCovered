module V2
  module Reports
    # NOTE: this tool is used only in QA purposes on dev/staging environments; route is not accessible on production
    class ChargePushReportsController < ApiController
      def show
        account = Account.where(id: params[:account_id]).first

        error_message =
          if params[:account_id].nil? || params[:month].nil? || params[:year].nil?
            'Missing one of the following parameters: account_id, month, year'
          elsif account.nil?
            'Account with provided ID does not exist'
          end

        return render json: { error: error_message } if error_message

        date = DateTime.new(params[:year].to_i, params[:month].to_i, 1)
        report = ::Reports::ChargePushReport.new(reportable: account, range_start: date, range_end: date.end_of_month).generate
        report.save

        render json: report.to_csv
      end
    end
  end
end
