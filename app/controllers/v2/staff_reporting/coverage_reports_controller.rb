


module V2
  module StaffReporting
    class CoverageReportsController < StaffReportingController
    
      def index
        super(:@coverage_reports, access_model(Reporting::CoverageReport))
      end
      
      def show
        @coverage_report = access_model(Reporting::CoverageReport, params[:coverage_report_id].to_i)
      end
      
      def latest
        @coverage_report = access_model(Reporting::CoverageReport).where(fixed_filters).order("report_time desc").limit(1).first
        render template: 'v2/shared/reporting/coverage_reports/show',
          status: :ok
      end
      
      private
      
        def fixed_filters
          @organizable.nil? ? {} : { status: 'ready', visible: true, coverage_determinant: (@organizable.reporting_coverage_reports_settings || {})['coverage_determinant'] || 'any' }
        end
        
        def default_filters
          {
            status: 'ready'
          }
        end
        
        def supported_filters
          {
            coverage_determinant: [ :scalar, :array, :interval ],
            report_time: [ :scalar, :array, :interval ]
          }.merge(@organizable ? {} : {
            status: [ :scalar, :array ],
            completed_at: [ :scalar, :array, :interval ],
            owner_type: [ :scalar, :array, :interval ],
            owner_id: [ :scalar, :array, :interval ],
            created_at: [ :scalar, :array, :interval ],
            updated_at: [ :scalar, :array, :interval ]
          })
        end
        
        def default_pagination_per
          50
        end
        
        def view_path
          'v2/shared/reporting/coverage_reports'
        end
        
        def v2_should_render
          { short: true, index: true }
        end
        
      # end private
    end
  end
end
