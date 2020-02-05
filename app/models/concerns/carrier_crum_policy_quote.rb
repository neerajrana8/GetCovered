# =Crum & Forester Policy Quote Functions Concern
# file: +app/models/concerns/carrier_crum_policy_quote.rb+

require "base64"
require 'fileutils'

module CarrierCrumPolicyQuote
  extend ActiveSupport::Concern

  included do
	  
	  # Download Quote Documents
	  #
	  
	  def get_document
      @get_document_response = {
        :error => true,
        :message => nil,
        :data => {}  
      }
      
	 		if quoted? && policy_application.carrier.id == 3
		 		
		 		crum_service = CrumService.new
		 		request_template = crum_service.build_request_template("get_document", { businessTransactionId: self.external_id.to_i })
            	      
        event = self.events.new(request: request_template.to_json, 
                                started: Time.now, status: "in_progress", 
                                verb: 'post', process: 'crum_get_quote_documents', 
                                endpoint: Rails.application.credentials.crum[:uri][:documents]) 
                                
		 		request = crum_service.get_documents(request_template)
		 		
		 		event.update completed: Time.now, response: request[:data], status: request[:error] ? "error" : "success"
		 		
		 		unless request[:error] 
			 		if request[:data].has_key?("base64Content")
				 		#FileUtils::mkdir_p "#{ Rails.root }/tmp/policy-quotes"
				 		file_path = Rails.root.join("tmp/policy-quotes/#{ request[:data]["fileName"] }")
				 		File.open(file_path, 'wb') do |file|
					 		file << Base64.decode64(request[:data]["base64Content"])	
					 	end
					 	
					 	if documents.attach(io: File.open(file_path), filename: request[:data]["fileName"], content_type: 'application/pdf')
							File.delete(file_path) if File.exist?(file_path) 	
						end
			 		end
			 	end
			 	
		 		@get_document_response[:error] = request[:error] ? true : false
		 		@get_document_response[:message] = request[:error] ? nil : "Quote documents recieved"
		 		@get_document_response[:data] = request[:data]

		 	else
		 		@get_document_response[:message] = "Quote inneligable to download documents"
		 	end
		 	
		 	return @get_document_response
		end
	  
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