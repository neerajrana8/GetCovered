##
# V2 Public Addresses Controller
# File: app/controllers/v2/public/addresses_controller.rb

module V2
  module Public
    class AddressesController < PublicController
	  	
	  	def index
		  	if params[:search].presence
			  	@addresses = Address.search_insurables(params[:search])
			  	@ids = @addresses.map { |a| a["_source"]["addressable_id"] }
			  	
			  	@insurables = Insurable.find(@ids)
					
					@response = []
					
					unless @insurables.nil?
						@insurables.each do |i|
							@response.push({
								id: @insurable.id,
								title: @insurable.title,
								enabled: @insurable.enabled,
								account_id: @insurable.account_id,
								agency_id: @insurable.account.agency_id,
								insurable_type_id: @insurable.insurable_type_id,
								category: @insurable.category,
								covered: @insurable.covered,
								created_at: @insurable.created_at,
								updated_at: @insurable.updated_at,
								addresses: @insurable.addresses,
								insurables: @insurable.insurables
							})							
						end
					end
					
					render json: @response.to_json,
               	 status: :ok 
			  else
			  	render json: [].to_json,
			  				 status: :ok
			  end	
			  
		  end
	  	 
	  end
	end
end