##
# V2 StaffAgency Claims Controller
# File: app/controllers/v2/staff_agency/claims_controller.rb

module V2
  module StaffAgency
    class ClaimsController < StaffAgencyController

      include ClaimsMethods
      
      before_action :set_claim, only: %i[update show attach_documents delete_documents process_claim]
      
      before_action :set_substrate, only: %i[index]
      
      def index
        if params[:short]
          super(:@claims, @substrate)
        else
          super(:@claims, @substrate, :insurable)
        end
      end
      
      def show; end
      
      def update
        if update_allowed?
          if @claim.update_as(current_staff, update_params)
            render :show,
              status: :ok
          else
            render json: @claim.errors,
                   status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
                 status: :unauthorized
        end
      end

      def delete_documents
        @claim.documents.where(id: params.permit(documents_ids: [])[:documents_ids]).purge
      end
      
      private
      
      def view_path
        super + '/claims'
      end
        
      def create_allowed?
        true
      end
        
      def update_allowed?
        true
      end
        
      def set_claim
        @claim = access_model(::Claim, params[:id])
      end
        
      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::Claim)
        elsif !params[:substrate_association_provided]
          @substrate = @substrate.claims
        end
      end

        
      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          created_at: [:scalar, :array, :interval]
        }
      end

      def supported_orders
        supported_filters(true)
      end
        
    end
  end # module StaffAgency
end
