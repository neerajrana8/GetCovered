# =Crum & Forester Policy Quote Functions Concern
# file: +app/models/concerns/carrier_crum_policy_quote.rb+

module CarrierCrumPolicyQuote
  extend ActiveSupport::Concern

  included do
	  
	  # Generate Quote
	  # 
	  
	  def crum_bind
      @bind_response = {
        :error => true,
        :message => nil,
        :data => {}  
      }
      
	 		if quoted? || error?
		 		if policy_application.carrier.id == 3
  	    
  	      crum_service = CrumService.new
  	      request_template = crum_service.build_request_template("bind", self)
            	      
          event = self.events.new(request: request_template.to_json, 
                                  started: Time.now, status: "in_progress", 
                                  verb: 'post', process: 'crum_bind', 
                                  endpoint: Rails.application.credentials.crum[:uri][:bind])  	      
  	    
          
          request = crum_service.bind(request_template)
          
          event.update completed: Time.now, response: request[:data], status: request[:error] ? "error" : "success"
          
          pp request[:data]
  	    
  	    end
      end
    end
    
  end
end