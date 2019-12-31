# =QBE Policy Quote Functions Concern
# file: +app/models/concerns/carrier_qbe_policy.rb+

module CarrierQbePolicyQuote
  extend ActiveSupport::Concern

  included do

    def set_qbe_external_reference
      
      return_status = false
      
      if external_reference.nil?
        
        loop do
          self.external_reference = Rails.application.credentials.qbe[:employee_id] + rand(36**7).to_s(36).upcase
          return_status = true
          
          break unless PolicyQuote.exists?(:external_reference => self.external_reference)
        end
      end
      
      update_column(:external_reference, self.external_reference) if return_status == true
      
      return return_status
      
    end
    
    # QBE Bind
  
    def qbe_bind
      @bind_response = {
        :error => true,
        :message => nil,
        :data => {}  
      }
      
	 		if quoted? || error?
		 		if policy_application.carrier.id == 1

	        event = events.new(
	          verb: 'post', 
	          format: 'xml', 
	          interface: 'SOAP',
	          process: 'send_qbe_policy_info', 
	          endpoint: Rails.application.credentials.qbe[:uri]
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
            
            if bind_status != "FAILURE"
              @bind_response[:error] = false
              @bind_response[:data][:status] = bind_status
              @bind_response[:data][:policy_number] = policy_number
            else
              @bind_response[:data][:status]
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
# 	    if self.policy_in_system? && 
# 		     self.carrier == Carrier.find_by_call_sign('QBE')
# 		     
# 	      to_return = nil
# 	  
# 	      if persisted? && 
# 	         status == "paid" &&
# 	         policy_in_system? &&
# 	         carrier.id == 2
# 	  
# 	        event = events.new(
# 	          verb: 'post', 
# 	          format: 'xml', 
# 	          interface: 'SOAP',
# 	          process: 'send_policy_info', 
# 	          endpoint: ENV.fetch("QBE_SOAP_URI")
# 	        )
# 	        
# 	        qbe_request_timer = {
# 	          total: nil,
# 	          start: nil,
# 	          end: nil
# 	        }
# 	  
# 	        qbe_service = QbeService.new(:action => 'SendPolicyInfo')
# 	  
# 	        qbe_service.build_request({}, true, true, self, self.users)
# 	  
# 	        event.request_xml = qbe_service.compiled_rxml
# 	  
# 	        if event.save
# 	  
# 	          start_time = Time.now
# 	          qbe_request_timer[:start] = start_time
# 	          event.started = start_time
# 	  
# 	          qbe_data = qbe_service.call()
# 	  
# 	          complete_time = Time.now
# 	          qbe_request_timer[:end] = complete_time
# 	          qbe_request_timer[:total] = (complete_time - start_time).to_f
# 	          event.completed = complete_time
# 	  
# 	          carrier_data["api_metrics"]["SendPolicyInfo"].push({ 
# 	            duration: "%.4f" % qbe_request_timer[:total],
# 	            date_time: Time.current.iso8601(9)
# 	          })
# 	        
# 		        event.response_xml = qbe_data[:data]
# 		        event.status = qbe_data[:error] ? 'error' : 'success'
# 		        
# 		        unless qbe_data[:error] # QBE Response Success
# 			        
# 	            xml_doc = Nokogiri::XML(qbe_data[:data])
# 	            xml_status = xml_doc.css('MsgStatusCd').children.to_s
# 	  
# 	            self.carrier_data['send_policy_info_response_status'] = xml_status
# 	  
# 	            if xml_status =~ /SUCCESS|WARNING/s
# 	  
# 	              self.status = xml_status == "SUCCESS" ? "synced" : "synced_with_warning"
# 	              self.policy_number = xml_doc.css('PolicyNumber').children.to_s
# 	              self.carrier_data['send_policy_info_resolved_on'] = Time.current
# 	              self.carrier_data['send_policy_info_resolved'] = true
# 	  
# 	              if status == "synced_with_warning"                   
# 	                self.carrier_data['send_policy_info_response'] = xml_doc.css('ExtendedStatusDesc')
# 	                                                                        .children
# 	                                                                        .to_s
# 	              end
# 	            else
# 	              self.status = "sync_error"
# 	              pp qbe_data
# 	            end
# 	  
# 	            if save()
# 	              accept() if auto_accept == true &&
# 	                       self.status =~ /synced|synced_with_warning/
# 	              to_return = self.sync_error? ? false : true
# 	            else
# 	              to_return = false
# 	            end		        	
# 		        
# 		        else # QBE Response Failure
# 		        
# 	            to_return = false
# 	            event.status = 'error'
# 	  
# 	            pp qbe_data
# 	            update status: "sync_error"
# 		        
# 		        end # QBE Response Complete
# 	  
# 	          if event.save
# 	            # do nothing
# 	          else
# 	            # event failed to save after the request returned
# 	            to_return = false
# 	            pp event.errors
# 	          end
# 	        else
# 	          # event failed to save after initialization
# 	          pp event.errors
# 	          to_return = false
# 	        end
# 	      end
# 	      return to_return
# 	    else
# 	      return nil
# 	    end      
    end
    
  end
end