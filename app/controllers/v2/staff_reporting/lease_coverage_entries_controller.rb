


module V2
  module StaffReporting
    class LeaseCoverageEntriesController < StaffReportingController
      
      before_action :set_coverage_report, only: [:index]
      before_action :set_parent, only: [:index]
    
      def index
        super(:@lease_coverage_entries, @parent.lease_coverage_entries)
      end
      
      
      private
      
        def set_coverage_report
          @coverage_report = access_model(Reporting::CoverageReport).where(
            { id: params[:coverage_report_id].to_i }
            .merge(@organizable.nil? ? {} : { visible: true, coverage_determinant: (@organizable.reporting_coverage_reports_settings || {})['coverage_determinant'] || 'any' })
          ).take || (raise StandardError.new("Invalid Reporting::CoverageReport ##{params[:coverage_report_id].to_i} request by Account ##{@organizable ? @organizable.id : "N/A (EMPEROR)"}, Staff ID ##{current_staff.id}!"))
          # these are used in the views
          @expand_ho4 = @coverage_report.expand_ho4?
          @determinant = @coverage_report.coverage_determinant
          @simplify_status = !@organizable.nil? && !params[:client_view]
        end
        
        def set_parent
          # just makes things a bit more efficient
          @parent = (params[:filter].blank? || params[:filter][:unit_coverage_entry_id].nil?) ? @coverage_report : access_model(Reporting::UnitCoverageEntry, params[:filter][:unit_coverage_entry_id].to_i)
        end
        
        def fixed_filters
          {}
        end
        
        def default_filters
          {}
        end
        
        def supported_filters
          {
            id: [:scalar, :array],
            report_time: [:scalar, :array, :interval],
            account_id: [:scalar, :array],
            unit_coverage_entry_id: [:scalar, :array],
            yardi_id: [:scalar, :array, :like],
            lease_id: [:scalar, :array],
            lessee_count: [:scalar, :array, :interval],
            status: [:scalar, :array],
            start_date: [:scalar, :array, :interval],
            end_date: [:scalar, :array, :interval],
            coverage_status_exact: [:scalar, :array],
            coverage_status_any: [:scalar, :array]
          }
        end
        
        def expand_coverage(det)
          return det if @expand_ho4 && !@simplify_status
          det = [det] unless det.class == ::Array
          return det.map do |d|
            if d == 'ho4'
              next ["external", "internal", "internal_and_external", "internal_or_external"]
            else
              if @expand_ho4
                if @simplify_status && d == 'internal'
                  next ["internal", "internal_and_external", "internal_or_external"]
                end
              else
                if ["external", "internal", "internal_and_external", "internal_or_external"].include?(d)
                  next "ho4"
                end
              end
            end
            next d
          end.flatten # we don't bother to uniq because it'd take cpu time for no reason, I think
        end
        
        def transform_filters(hash)
          return(hash.map do |k,v|
            if k == 'coverage_status'
              ["coverage_status_#{@determinant}", v]
            else
              if !@organizable.nil? && ['coverage_status_exact', 'coverage_status_any'].include?(k)
                nil
              else
                [k,v]
              end
            end
          end.compact.to_h)
        end
        
        def transform_orders(hash)
          return nil if hash.nil?
          if hash[:column].class == ::Array
            hash[:column].map!{|k| k == 'coverage_status' ? "coverage_status_#{@determinant}" : k }
          elsif hash[:column] == 'coverage_status'
            hash[:column] = "coverage_status_#{@determinant}"
          end
          return hash
        end
      
        def default_pagination_per
          50
        end
        
        def view_path
          'v2/shared/reporting/lease_coverage_entries'
        end
        
        def v2_should_render
          { short: true, index: true }
        end
        
        def v2_default_to_short
          true
        end
        
        def fake_report
          # MOOSE WARNING not implemented
        end

    end # end controller
  end
end
