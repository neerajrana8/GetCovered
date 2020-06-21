# =MSI Policy Quote Functions Concern
# file: +app/models/concerns/carrier_qbe_policy.rb+

module CarrierMsiPolicyQuote
  extend ActiveSupport::Concern

  included do

    # MOOSE WARNING: PolicyQuote#bind_policy should call this boi if necessary
    def set_msi_external_reference
      
      return_status = true # MOOSE WARNING: change it?
      
    end
    
    # MSI build coverages
    
    def msi_build_coverages
      self.policy_application.coverage_selections.select{|covsel| covsel['selection'] != false }.each do |covsel|
        self.policy.policy_coverages.create(
          policy_application: self.policy_application,
          title: covsel['title'],
          designation: covsel['uid'],
          schedule: covsel['category'],
          limit: covsel['category'] != 'coverage' ? 0 : [nil, true].include?(covsel['selection']) ? 0 : covsel['selection'].to_i,
          deductible: covsel['category'] != 'deductible' ? 0 : [nil, true].include?(covsel['selection']) ? 0 : covsel['selection'].to_i,
          enabled: true
        )
      end
    end
    
    # MSI Bind
  
    def msi_bind
      # MOOSE WARNING: modify qbe bind methods here
      @bind_response = {
        :error => true,
        :message => nil,
        :data => {}  
      }
      
	 		if accepted? && policy.nil?
		 		if policy_application.carrier_id == 5

	        event = events.new(
	          verb: 'post', 
	          format: 'xml', 
	          interface: 'SOAP',
	          process: 'send_qbe_policy_info', 
	          endpoint: Rails.application.credentials.qbe[:uri][ENV["RAILS_ENV"].to_sym]
	        )
          
          carrier_agency = CarrierAgency.where(agency: account.agency, carrier: self.policy_application.carrier).take
          
	        qbe_service = QbeService.new(:action => 'SendPolicyInfo')
	        qbe_service.build_request({ agent_code: carrier_agency.external_carrier_id }, true, true, self, self.policy_application.users)
	  
 	        event.request = qbe_service.compiled_rxml
 			 		event.started = Time.now
			 		
			 		qbe_data = qbe_service.call()
			 		
			 		event.completed = Time.now
			 		event.response = qbe_data[:data]
 			 		event.status = qbe_data[:error] ? 'error' : 'success'
			 		
			 		event.save
			 		
          unless qbe_data[:error] # QBE Response success
                    
 	          xml_doc = Nokogiri::XML(qbe_data[:data])
 	          bind_status = xml_doc.css('MsgStatusCd').children.to_s
            policy_number = xml_doc.css('PolicyNumber').children.to_s
            notify_of_error = false
            
            if bind_status != "FAILURE"
              @bind_response[:error] = false
              @bind_response[:data][:status] = bind_status
              @bind_response[:data][:policy_number] = policy_number
              notify_of_error = bind_status == "WARNING" ? true : false 
            else
              @bind_response[:data][:status]
              notify_of_error = true
            end
            
            if notify_of_error
              message = "Get Covered Bind Warning.\n"
              message += "Application Environment: #{ ENV["RAILS_ENV"] }\n"
              message += "Bind Status: #{ bind_status }\n"
              message += bind_status == "WARNING" ? "Policy: #{ policy_number }\n" : "N/A"
              message += "Timestamp: #{ DateTime.now.to_s(:db) }\n\n"
              message_components = []
              
            	xml_doc.css('ExtendedStatus').each do |status|
              	unless message_components.any? { |mc| mc[:status_cd] == status.css('ExtendedStatusCd').children.to_s }
	              	message_components << {
		              	:status_cd => status.css('ExtendedStatusCd').children.to_s,
		              	:status_message => status.css('ExtendedStatusDesc').children.to_s
	              	}
              	end		              
              end

            	message_components.each do |mc|
              	message += "#{ mc[:status_cd] }\n"
              	message += "#{ mc[:status_message] }\n\n"	
              end
              
              message += event.request
              
              PolicyBindWarningNotificationJob.perform_later(message: message)
              
            end            
            
          else # QBE Response failure
            @bind_response[:message] = "QBE Bind Failure"
          end
			 	else
			 		@bind_response[:message] = "Carrier must be QBE to bind residential quote"
			 	end
		 	else
		 		@bind_response[:message] = "Status must be quoted or error to bind quote"
		 	end 
		 	
		 	return @bind_response  
     
    end
    
  end
end
