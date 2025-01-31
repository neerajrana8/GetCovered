##
# V2 StaffAgency Invoices Controller
# File: app/controllers/v2/staff_agency/invoices_controller.rb

module V2
  module StaffAgency
    class InvoicesController < StaffAgencyController
      
      before_action :set_invoice,
        only: [:update, :show]
            
      before_action :set_substrate,
        only: [:index]
      
      def index
        if params[:short]
          super(:@invoices)
        else
          super(:@invoices)
        end
      end
      
      def show
      end
      
      def update
        if update_allowed?
          if @invoice.update(update_params)
            render :show,
              status: :ok
          else
            render json: @invoice.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      
      private
      
        def view_path
          super + "/invoices"
        end
        
        def update_allowed?
          true
        end
        
        def set_invoice
          @invoice = access_model(::Invoice, params[:id])
        end
        
        def set_substrate
          super
          if @substrate.nil?
            @substrate = access_model(::Invoice)
          elsif !params[:substrate_association_provided]
            @substrate = @substrate.invoices
          end
        end
        def update_params
          return({}) if params[:invoice].blank?
          to_return = {}
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
