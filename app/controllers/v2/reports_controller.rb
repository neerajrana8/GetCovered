module V2
  class ReportsController < V2Controller
    include ActionController::MimeResponds

    before_action :authenticate_staff!
    before_action :is_staff?
    before_action :set_reportable
    before_action :find_report, only: [:show]

    def index
      super(:@reports, @reportable.reports)
    end

    def show
      respond_to do |format|
        format.json
        format.csv do
          send_data @report.to_csv, filename: file_name('csv')
        end
        format.xlsx do
          send_data @report.to_xlsx.read, type: "application/xlsx", filename: file_name('xlsx')
        end
      end
    end

    def available_range
      render json: (params[:report_format] && params[:report_format] != 'all' ? {
        report_start: @reportable.reports.where(format: params[:report_format]).minimum(:created_at),
        report_end: @reportable.reports.where(format: params[:report_format]).maximum(:created_at)
      } : {
        report_start: @reportable.reports.minimum(:created_at),
        report_end: @reportable.reports.maximum(:created_at)
      }), status: :ok
    end

    def generate
      success, result, status = generate_report(type: params[:type], reportable: @reportable)
      if success
        respond_to do |format|
          format.json { render json: { data: result.data } }
          format.csv { send_data result.to_csv, filename: "#{result.type.underscore.split('/').last}-#{Date.today}.csv" }
        end
      else
        render json: { message: result[:message], type: result[:type] }, status: status
      end
    end

    private

    def file_name(extension)
      "#{@report.type.underscore.split('/').last}-#{@report.created_at || Date.today}.#{extension}"
    end

    def generate_report(type:, reportable:)
      report_class = type.constantize
      if report_class.ancestors.include?(Report)
        new_report = report_class.new(reportable: reportable)
        return true, new_report.generate # data always should be present unless unpredicted errors
      else
        return false, { type: :wrong_report_type, message: 'Wrong report type' }, :unprocessable_entity
      end
    rescue NameError
      return false, { type: :wrong_report_type, message: 'Wrong report type' }, :unprocessable_entity
    end

    def is_staff?
      render json: { error: "Unauthorized access" }, status: :unauthorized unless current_staff.present?
    end

    def set_reportable
      params.each do |name, value|
        if name =~ /(.+)_id$/
          @reportable = $1.classify.constantize.find(value)
        end
      end

      # Guard covers the case when params doesn't contain the key like 'class_name_id'.
      unless defined?(@reportable)
        render json: { success: false, message: 'Reportable id was not found in request url' }, status: :not_found
      end
    end

    def find_report
      @report = @reportable.reports.find(params['id'])
    end

    def supported_filters(called_from_orders = false)
      @calling_supported_orders = called_from_orders
      {
        id: [:scalar, :array],
        type: [:scalar, :like],
        created_at: [:scalar, :array, :interval]
      }
    end

    def supported_orders
      supported_filters(true)
    end
  end
end
