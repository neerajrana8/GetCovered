


module V2
  module StaffReporting
    class LeaseUserCoverageEntriesController < StaffReportingController
      
      before_action :set_coverage_report, only: [:index]
      before_action :set_parent, only: [:index]
    
      def index
        super(:@lease_user_coverage_entries, @parent.nil? ? @coverage_report.lease_user_coverage_entries : @parent.lease_user_coverage_entries)
      end
      
      
      private
      
        def set_coverage_report
          @coverage_report = access_model(Reporting::CoverageReport).where(
            { id: params[:coverage_report_id].to_i }
            .merge(@organizable.nil? ? {} : { visible: true, coverage_determinant: (@organizable.reporting_coverage_reports_settings || {})['coverage_determinant'] || 'any' })
          ).take || (raise StandardError.new("Invalid Reporting::CoverageReport ##{params[:coverage_report_id].to_i} request by Account ##{@organizable ? @organizable.id : "N/A (EMPEROR)"}, Staff ID ##{current_staff.id}!"))
          # these are used in the views
          @expand_ho4 = @coverage_report.expand_ho4?
          @determinant = 'exact'
          @simplify_status = !@organizable.nil? && !params[:client_view]
        end
      
        def set_parent
          @parent = params[:parent_id].nil? ? nil : access_model(Reporting::UnitCoverageEntry, params[:parent_id].to_i)
        end
        
        def fixed_filters
          {}
        end
        
        def default_filters
          {}
        end
        
        def supported_filters
          {
            lease_user_id: [:scalar, :array],
            lessee: [:scalar],
            current: [:scalar],
            report_time: [:scalar, :array, :interval],
            first_name: [:scalar, :array, :like],
            last_name: [:scalar, :array, :like],
            email: [:scalar, :array, :like],
            yardi_id: [:scalar, :array, :like],
            policy_id: [:scalar, :array],
            policy_number: [:scalar, :array, :like],
            coverage_status_exact: [:scalar, :array],
            unit_coverage_entry_id: [:scalar, :array],
            account_id: [:scalar, :array]
          }
        
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
              if !@organizable.nil? && ['coverage_status_exact', 'coverage_status_numeric', 'coverage_status_any'].include?(k)
                nil
              else
                [k,v]
              end
            end
          end.compact.to_h)
        end
        
        def transform_orders(hash)
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
          'v2/shared/reporting/lease_user_coverage_entries'
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
