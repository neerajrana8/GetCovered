##
# V2 StaffAgency Histories Controller
# File: app/controllers/v2/staff_agency/histories_controller.rb

module V2
  module StaffAgency
    class HistoriesController < StaffAgencyController
      before_action :set_substrate,
        only: [:index]
      
      def index(objects = @substrate)
        super(:@histories, objects)
      end

      def index_recordable
        @using_recordable_index = true
        params[:sort] = { column: 'created_at', direction: 'desc' }
        objects = access_model(params[:recordable_type], params[:id]).histories
        index(objects)
        remove_instance_variable(:@using_recordable_index)
        render template: view_path + "/#{params[:short] ? 'short' : 'index'}.json.jbuilder"
      end

      def index_authorable
        @using_authorable_index = true
        params[:sort] = { column: 'created_at', direction: 'desc' }
        objects = access_model(params[:authorable_type], params[:id]).authored_histories
        index(objects)
        remove_instance_variable(:@using_authorable_index)
        render template: view_path + "/#{params[:short] ? 'short' : 'index'}.json.jbuilder"
      end

      private

      def view_path
        super + '/histories'
      end

      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::History)
        elsif !params[:substrate_association_provided]
          @substrate = @substrate.histories
        end
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end # module StaffAgency
end
