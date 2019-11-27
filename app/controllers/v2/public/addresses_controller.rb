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
			  
					render json: @insurables.to_json({ :include => [:addresses, :insurables] }),
               	 status: :ok 
			  else
			  	render json: [].to_json,
			  				 status: :ok
			  end	
			  
		  end
	  	 
	  end
	end
end