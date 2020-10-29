##
# V2 StaffAccount Claims Controller
# File: app/controllers/v2/staff_account/claims_controller.rb

module V2
  module StaffAccount
    class ClaimsController < StaffAccountController

      include ClaimsMethods
      
      before_action :set_claim, only: %i[update show  delete_documents process_claim]
      before_action :set_substrate, only: %i[index]
      
      def index
        if params[:short]
          super(:@claims, @substrate)
        else
          super(:@claims, @substrate, :insurable)
        end
      end
      
      def show; end

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
        
      def update_params
        return({}) if params[:claim].blank?

        params.require(:claim).permit(
          :description, :insurable_id, :policy_id, :subject,
          :time_of_loss, :type_of_loss, :staff_notes, documents: []
        )
      end
        
      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          created_at: [:scalar, :array, :interval],
          time_of_loss: [:scalar, :array, :interval]
        }
      end

      def supported_orders
        supported_filters(true)
      end
        
    end
  end # module StaffAccount
end
