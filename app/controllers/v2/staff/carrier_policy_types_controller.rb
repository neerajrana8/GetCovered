module V1
  module Staff
    class CarrierPolicyTypesController < StaffController
      before_action :set_carrier_policy_type, only: [:edit, :show, :update, :destroy]
      before_action :only_super_admins
      
      def index
        @carrier_policy_types = CarrierPolicyType.all
        respond_to do |format|
          format.html
          format.json { render json: @carrier_policy_types }
        end
      end
      
      def show; end
      
      def new
        @carrier_policy_type = CarrierPolicyType.new
        respond_to do |format|
          format.html # new.html.erb
          format.json { render json: @carrier_policy_type }
        end
      end

      def edit; end
      
      def create
        @carrier_policy_type = CarrierPolicyType.new(carrier_policy_type_params)  
        respond_to do |format|
          if @carrier_policy_type.save
            format.html { redirect_to @carrier_policy_type, notice: 'CarrierPolicyType was successfully created.' }
            format.json { render json: @carrier_policy_type, status: :created, location: @carrier_policy_type }
          else
            format.html { render action: "new" }
            format.json { render json: @carrier_policy_type.errors, status: :unprocessable_entity }
          end
        end
      end

      def update        
        respond_to do |format|
          if @carrier_policy_type.update_attributes(carrier_policy_type_params)
            format.html { redirect_to @carrier_policy_type, notice: 'CarrierPolicyType was successfully updated.' }
            format.json { head :no_content }
          else
            format.html { render action: "edit" }
            format.json { render json: @carrier_policy_type.errors, status: :unprocessable_entity }
          end
        end
      end

      def destroy
        @carrier_policy_type.destroy
        respond_to do |format|
          format.html { redirect_to carrier_policy_types_url }
          format.json { head :no_content }
        end
      end

      private
      
      def set_carrier_policy_type
        @carrier_policy_type = CarrierPolicyType.find(params[:id])
      end
      
      def view_path
        super + '/carrier_policy_types'
      end
      
      def carrier_policy_type_params
        params.require(:carrier_policy_type).permit(:policy_type_id, :carrier_id)
      end
    end
  end
end
