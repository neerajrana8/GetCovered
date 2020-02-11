##
# V2 StaffAgency Carrier Insurable Profiles Controller
# File: app/controllers/v2/staff_agency/carrier_insurable_profiles_controller.rb

module V2
  module StaffAgency
    class CarrierInsurableProfilesController < StaffAgencyController
      
      before_action :set_carrier_insurable_profile
      
      def show
        render json: @carrier_insurable_profile.to_json,
               status: :ok
      end
      
      def update
        params_set = nil
        
        switch @carrier_insurable_profile.carrier_id
        when 1
          params_set = qbe_params
        when 3
          params_set = crum_params
        end
        
        if @carrier_insurable_profile.update(params_set)
          render json: @carrier_insurable_profile.to_json,
                 status: :ok
        else
          render json: @carrier_insurable_profile.errors.to_json,
                 status: 422
        end
      end
    
      private
      
        def set_carrier_insurable_profile
          @carrier_insurable_profile = CarrierInsurableProfile.find(params[:id])  
        end
      
        def qbe_params
          params.require(:carrier_insurable_profile).permit(traits: { :ppc, :bceg, :gated, :city_limit, :alarm_credit,
                                                                      :pref_facility, :occupancy_type, :construction_type,
                                                                      :construction_year, :protection_device_cd, :professionally_managed,
                                                                      :professionally_managed_year }) 
        end
        
        def crum_params
          
          
        end
      
    end
  end
end