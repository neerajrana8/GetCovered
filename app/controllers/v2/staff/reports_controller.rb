##
# V1 Account Reports Controller
# file: app/controllers/v1/account/reports_controller.rb

module V1
  module Account
    class ReportsController < StaffController
      before_action :set_owner
      before_action :set_report,
        only: :show
    
      def index
        super(:@reports, @owner.reports)
      end
      
      def show
      end
      
      def available_range
        render json: (params[:format] && params[:format] != 'all' ? {
          report_start: @owner.reports.where(format: params[:format]).minimum(:created_at),
          report_end: @owner.reports.where(format: params[:format]).maximum(:created_at)
        } : {
          report_start: @owner.reports.minimum(:created_at),
          report_end: @owner.reports.maximum(:created_at)
        }), status: :ok
      end
    
      private

        def view_path
          super + '/reports'
        end
      
        def set_owner
          
          available_paths = ['/communities', '/buildings', '/units', 
                             '/master-policies', '/staffs', '/accounts']
          
          @owner = nil
          path = request.fullpath
          
          available_paths.each do |ap|
            
            modified_ap = ap.gsub(/-/, "_").tr('/','')
            unless modified_ap == 'accounts'
              @owner = @account.send(modified_ap)
                               .find(params["#{modified_ap.singularize}_id".to_sym]) if path.include?(ap)  
            else
              @owner = @account
            end
          end
          
        end
        
        def set_report
          @report = @owner.reports.find(params[:id])
        end
    
        def supported_filters
          {
            id: [ :scalar, :array ],
            format: [ :scalar, :array ],
            created_at: [:scalar, :array, :interval]
          }
        end
    end
  end
end
