##
# V2 StaffSuperAdmin Invoices Controller
# File: app/controllers/v2/staff_super_admin/invoices_controller.rb

module V2
  module StaffSuperAdmin
    class InvoicesController < StaffSuperAdminController
      
      before_action :set_invoice, only: [:show]
            
      def index
        super(:@invoices, Invoice)
      end
      
      def show
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
            id: [:scalar, :array],
            created_at: [:scalar, :array, :interval],
            updated_at: [:scalar, :array, :interval],
            number: [:scalar, :array],
            status: [:scalar, :array],
            due_date: [:scalar, :array, :interval],
            total: [:scalar, :array, :interval],
            subtotal: [:scalar, :array, :interval],
            tax: [:scalar, :array, :interval],
            tax_percent: [:scalar, :array, :interval],
            user_id: [:scalar, :array],
            invoiceable_product_id: [:scalar, :array],
            invoiceable_product_type: [:scalar, :array],
            #policy: {
            #  id: [:scalar, :array],
            #  number: [:scalar, :array],
            #  account_id: [:scalar, :array]
            #},
            user: {
              id: [:scalar, :array],
              profile: {
                first_name: [:scalar],
                last_name: [:scalar],
                full_name: [:scalar]
              }
            }
          }
        end

        def supported_orders
          supported_filters(true)
        end
        
    end
  end # module StaffSuperAdmin
end
