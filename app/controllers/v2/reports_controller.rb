module V2
  class ReportsController < V2Controller
    before_action :authenticate_staff!
    before_action :is_staff?
    before_action :set_reportable
    before_action :find_report, only: [:show]

    def index
      super(:@reports, @reportable.reports)
    end

    def show; end

    def available_range
      render json: (params[:report_format] && params[:report_format] != 'all' ? {
        report_start: @reportable.reports.where(format: params[:report_format]).minimum(:created_at),
        report_end: @reportable.reports.where(format: params[:report_format]).maximum(:created_at)
      } : {
        report_start: @reportable.reports.minimum(:created_at),
        report_end: @reportable.reports.maximum(:created_at)
      }), status: :ok
    end

    private

    def is_staff?
      render json: { error: "Unauthorized access"}, status: :unauthorized unless current_staff.present?
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
        format: [:scalar, :like],
        created_at: [:scalar, :like]
      }
    end

    def supported_orders
      supported_filters(true)
    end
  end
end
