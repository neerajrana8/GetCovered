##
# V2 StaffSuperAdmin Histories Controller
# File: app/controllers/v2/staff_super_admin/histories_controller.rb

module V2
  module StaffSuperAdmin
    class HistoriesController < StaffSuperAdminController
      
      def index_recordable
          @using_recordable_index = true
          params[:sort] = { column: 'created_at', direction: 'desc' }
          index(:@histories, access_model(params[:recordable_type], params[:id]).histories)
          remove_instance_variable(:@using_recordable_index)
          render template: view_path + "/#{params[:short] ? "short" : "index"}.json.jbuilder"
      end

      def index_authorable
          @using_authorable_index = true
          params[:sort] = { column: 'created_at', direction: 'desc' }
          index(:@histories, access_model(params[:authorable_type], params[:id]).authored_histories)
          remove_instance_variable(:@using_authorable_index)
          render template: view_path + "/#{params[:short] ? "short" : "index"}.json.jbuilder"
      end
      
      private

        def view_path
          super + "/histories"
        end
        
        def supported_filters
          if @using_recordable_index
            return({
              created_at: [:scalar, :array, :interval],
              action: [:scalar, :array],
              authorable_id: [:scalar, :array],
              authorable_type: [:scalar, :array]
            })
          elsif @using_authorable_index
            return({
              created_at: [:scalar, :array, :interval],
              action: [:scalar, :array],
              recordable_id: [:scalar, :array],
              recordable_type: [:scalar, :array]
            })
          end
          return({})
        end

        def supported_orders
          supported_filters
        end
        
    end
  end # module StaffSuperAdmin
end
