


module V2
  module StaffReporting
    class CoverageEntriesController < StaffReportingController
    
      include Concerns::Reporting::CoverageEntriesMethods
      
      before_action :set_coverage_report, only: %i[index]
    
      def index
        super(:@coverage_entries, @coverage_report.coverage_entries.where(status: 'generated'))
      end
      
      
      private
      
        def set_coverage_report
          @coverage_report = access_model(Reporting::CoverageReport).where(
            { id: params[:coverage_report_id].to_i }
            .merge(@organizable.nil? ? {} : { visible: true, coverage_determinant: (@organizable.reporting_coverage_reports_settings || {})['coverage_determinant'] || 'any' })
          ).take || (raise StandardError.new("Invalid Reporting::CoverageReport ##{params[:coverage_report_id].to_i} request by Account ##{@organizable ? @organizable.id : "N/A (EMPEROR)"}, Staff ID ##{current_staff.id}!"))
          @expand_ho4 = @coverage_report.expand_ho4?
          @determinant = @coverage_report.coverage_determinant
        end
        
        def fixed_filters
          @coverage_report.owner_type.nil? ? {} : { status: 'generated' }
        end
        
        def default_filters
          {
            status: 'generated'
          }
        end
        
        def supported_filters
          @sf ||= {
            id: [:scalar, :array],
            reportable_category: [:scalar, :array],
            reportable_title: [:scalar, :array, :like],
            reportable_description: [:scalar, :array, :like],
            coverage_report_id: [:scalar, :array],
            reportable_type: [:scalar, :array],
            reportable_id: [:scalar, :array],
            parent_id: [:scalar, :array],
            
            total_units: [ :scalar, :array, :interval ]
          }.merge(
            ['total', 'percent'].map do |quantity|
              (['master', 'ho4', 'no'] + (@expand_ho4 ? ['internal', 'external'] : [])).map do |coverage|
                "#{quantity}_units_with_#{coverage}_policy"
              end
            end.flatten.map{|prop| [prop.to_sym, [:scalar, :array, :interval]] }.to_h
          )
        end
      
        def default_pagination_per
          50
        end
        
        def view_path
          'v2/shared/reporting/coverage_entries'
        end
        
        def v2_should_render
          { short: true, index: true }
        end
        
        def v2_default_to_short
          true
        end

    end # end controller
  end
end
