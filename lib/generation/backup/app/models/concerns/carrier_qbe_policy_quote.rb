# =QBE Policy Quote Functions Concern
# file: +app/models/concerns/carrier_qbe_policy.rb+

module CarrierQbePolicyQuote
  extend ActiveSupport::Concern

  included do
    
    # QBE Bind
  
    def qbe_bind
	    if self.policy_in_system? && 
		     self.carrier == Carrier.find_by_call_sign('QBE')
		     
	      to_return = nil
	  
	      if persisted? && 
	         status == "paid" &&
	         policy_in_system? &&
	         carrier.id == 2
	  
	        event = events.new(
	          verb: 'post', 
	          format: 'xml', 
	          interface: 'SOAP',
	          process: 'send_policy_info', 
	          endpoint: ENV.fetch("QBE_SOAP_URI")
	        )
	        
	        qbe_request_timer = {
	          total: nil,
	          start: nil,
	          end: nil
	        }
	  
	        qbe_service = QbeService.new(:action => 'SendPolicyInfo')
	  
	        qbe_service.build_request({}, true, true, self, self.users)
	  
	        event.request_xml = qbe_service.compiled_rxml
	  
	        if event.save
	  
	          start_time = Time.now
	          qbe_request_timer[:start] = start_time
	          event.started = start_time
	  
	          qbe_data = qbe_service.call()
	  
	          complete_time = Time.now
	          qbe_request_timer[:end] = complete_time
	          qbe_request_timer[:total] = (complete_time - start_time).to_f
	          event.completed = complete_time
	  
	          carrier_data["api_metrics"]["SendPolicyInfo"].push({ 
	            duration: "%.4f" % qbe_request_timer[:total],
	            date_time: Time.current.iso8601(9)
	          })
	        
		        event.response_xml = qbe_data[:data]
		        event.status = qbe_data[:error] ? 'error' : 'success'
		        
		        unless qbe_data[:error] # QBE Response Success
			        
	            xml_doc = Nokogiri::XML(qbe_data[:data])
	            xml_status = xml_doc.css('MsgStatusCd').children.to_s
	  
	            self.carrier_data['send_policy_info_response_status'] = xml_status
	  
	            if xml_status =~ /SUCCESS|WARNING/s
	  
	              self.status = xml_status == "SUCCESS" ? "synced" : "synced_with_warning"
	              self.policy_number = xml_doc.css('PolicyNumber').children.to_s
	              self.carrier_data['send_policy_info_resolved_on'] = Time.current
	              self.carrier_data['send_policy_info_resolved'] = true
	  
	              if status == "synced_with_warning"                   
	                self.carrier_data['send_policy_info_response'] = xml_doc.css('ExtendedStatusDesc')
	                                                                        .children
	                                                                        .to_s
	              end
	            else
	              self.status = "sync_error"
	              pp qbe_data
	            end
	  
	            if save()
	              accept() if auto_accept == true &&
	                       self.status =~ /synced|synced_with_warning/
	              to_return = self.sync_error? ? false : true
	            else
	              to_return = false
	            end		        	
		        
		        else # QBE Response Failure
		        
	            to_return = false
	            event.status = 'error'
	  
	            pp qbe_data
	            update status: "sync_error"
		        
		        end # QBE Response Complete
	  
	          if event.save
	            # do nothing
	          else
	            # event failed to save after the request returned
	            to_return = false
	            pp event.errors
	          end
	        else
	          # event failed to save after initialization
	          pp event.errors
	          to_return = false
	        end
	      end
	      return to_return
	    else
	      return nil
	    end      
    end
    
  end
end