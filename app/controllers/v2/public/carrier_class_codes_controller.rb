##
# V2 Carrier Class Codes Controller
# File: app/controllers/v2/public/insurables_controller.rb

module V2
  module Public
    class CarrierClassCodesController < PublicController
	  
	  	def index
		  	@state_code = params[:state_code].presence ? ["CW", "FL", "TX"].include?(params[:state_code]) ? params[:state_code] : "CW" : "CW"
		  	@major_category = params[:major_category].presence ? params[:major_category].delete_prefix('"').delete_suffix('"') : nil
		  	
		  	puts "QUERY: enabled: true, state_code: #{ @state_code }, major_category: #{ @major_category.nil? ? 'nil' : @major_category.to_s }"
		  	
		  	@class_codes = @major_category.nil? ? CarrierClassCode.where(enabled: true, state_code: @state_code) : 
		  	                                      CarrierClassCode.where(enabled: true, state_code: @state_code, major_category: @major_category.to_s)
                                                
        render json: @class_codes.order("major_category").to_json,
               status: :ok
	      
		  end
	   
	  end
	end
end
