##
# V1 Account Histories Controller
# file: app/controllers/v1/account/histories_controller.rb

module V1
  module Account
    class HistoriesController < StaffController
      before_action :set_owner

      def index
        params[:sort] = { column: 'created_at', direction: 'desc' }
        super(:@histories, @owner.histories)
      end

      private
        
        def set_owner
          
          available_paths = ['/agencies', '/accounts', '/communities', 
                             '/buildings', '/units', '/master-policies', 
                             '/policies', '/payments', '/claims', 
                             '/leases', '/carriers',
                             '/users', '/staffs']
          
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
        
        def view_path
          super + '/histories'
        end

        def supported_filters
          {
            created_at: [ :scalar, :array, :interval ]
          }
        end
        
    end
  end
end
