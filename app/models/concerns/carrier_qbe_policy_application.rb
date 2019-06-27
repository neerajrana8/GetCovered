# =QBE Policy Application Functions Concern
# file: +app/models/concerns/carrier_qbe_policy.rb+

module CarrierQbePolicyApplication
  extend ActiveSupport::Concern

  included do
	  
	  # QBE Quote
	  # 
	  # Takes Policy Application data and sends to QBE to create a quote
	  
	  def qbe_quote
	    if self.policy_in_system? && 
		     self.carrier == Carrier.find_by_call_sign('QBE')
		    
	      to_return = nil
	      region = address.region.upcase
	      
	      if persisted? && 
	         status == "in_progress" &&
	         carrier.id == 2
	  
	        event = events.new(
	          verb: 'post', 
	          format: 'xml', 
	          interface: 'SOAP',
	          process: 'get_min_prem', 
	          endpoint: ENV.fetch("QBE_SOAP_URI")
	        )
	             
	        qbe_request_timer = {
	          total: nil,
	          start: nil,
	          end: nil
	        }
	  
	        qbe_service = QbeService.new(:action => 'getMinPrem')
	  
	        alt_premium_discount = paid_in_full? ? 1.01 : 0.98
	        base_premium = premium.to_f
	        alt_premium = (base_premium * alt_premium_discount).to_i
	  
	        qbe_request_options = { 
	          prop_city: community.address.locality,
	          prop_county: community.address.county,
	          prop_state: community.address.region,
	          prop_zipcode: community.address.combined_postal_code,
	          city_limit: community.in_city_limits? ? 1 : 0,
	          units_on_site: community.units.count,
	          age_of_facility: community.construction_year,
	          gated_community: community.gated_access == true ? 1 : 0,
	          prof_managed: community.professionally_managed == true ? 1 : 0,
	          prof_managed_year: community.professionally_managed_year.nil? ? "" : 
	                                                                          community.professionally_managed_year,
	          effective_date: effective_date.strftime("%m/%d/%Y"),
	          premium: premium.to_f / 100,
	          premium_pif: premium.to_f / 100,
	          num_insured: insured.length,
	          lia_amount: liability_coverage.nil? ? 10000 : liability_coverage.coverage_limits["liability"].to_f / 100
	        }
	  
	        qbe_service.build_request(qbe_request_options)
	  
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
	  
	          carrier_data["api_metrics"]["getMinPrem"].push({ 
	            duration: "%.4f" % qbe_request_timer[:total],
	            date_time: Time.current.iso8601(9)
	          })
	        
		        event.response_xml = qbe_data[:data]
		        event.status = qbe_data[:error] ? 'error' : 'success'

		        unless qbe_data[:error] # QBE Response Success

	            xml_doc = Nokogiri::XML(qbe_data[:data])  
	            xml_min_prem = xml_doc.css('//Additional_Premium')
	            
	            response_hash = {
	              min_premium: (xml_min_prem.attribute('min_premium').value.to_f * 100).to_i,
	              min_premium_paid_in_full: (xml_min_prem.attribute('min_premium_pif').value.to_f * 100).to_i,
	              tax: (xml_min_prem.attribute('tax').value.to_f * 100).to_i,
	              tax_paid_in_full: (xml_min_prem.attribute('tax_pif').value.to_f * 100).to_i,
	              consent_to_rate_precentage: xml_min_prem.attribute('ctr_precentage').value,
	              consent_to_rate_precentage_paid_in_full: xml_min_prem.attribute('ctr_precentage_pif').value,
	              total_premium: (xml_min_prem.attribute('total_premium').value.to_f * 100).ceil().to_i,
	              total_premium_paid_in_full: (xml_min_prem.attribute('total_premium_pif').value.to_f * 100).ceil().to_i,
	              additional_insured_charge: xml_min_prem.attribute('number_named_insured_chrg').value.to_i,
	              payments: {
	                month: {
	                  first_payment: (xml_min_prem.attribute('monthly_down_pymnt').value.to_f * 100).to_i,
	                  remaining_payments: (xml_min_prem.attribute('monthly_subsequent_pymnt').value.to_f * 100).to_i,
	                  next_payment_date: xml_min_prem.attribute('next_installment_date').value
	                },
	                quarter_year: {
	                  first_payment: (xml_min_prem.attribute('quarterly_down_payment').value.to_f * 100).to_i,
	                  remaining_payments: (xml_min_prem.attribute('monthly_subsequent_pymnt').value.to_f * 100).to_i,
	                  next_payment_date: xml_min_prem.attribute('quarterly_next_installment_date').value
	                },
	                half_year: {
	                  first_payment: (xml_min_prem.attribute('semi_down_payment').value.to_f * 100).to_i,
	                  remaining_payments: (xml_min_prem.attribute('semi_subsequent_pymnt').value.to_f * 100).to_i,
	                  next_payment_date: xml_min_prem.attribute('semi_next_installment_date').value
	                }
	              }
	            }
	            
	            self.status = "verifying"
	            self.carrier_data['get_min_prem_response'] = response_hash
	            self.carrier_data['get_min_prem_resolved_on'] = Time.current
	            self.carrier_data['get_min_prem_resolved'] = true
	            
	            unless region == "FL"
	              self.tax = self.paid_in_full? ? Integer(carrier_data['get_min_prem_response'][:tax_paid_in_full]) : 
	                                              Integer(carrier_data['get_min_prem_response'][:tax])
	              self.total_premium = self.paid_in_full? ? Integer(carrier_data['get_min_prem_response'][:total_premium_paid_in_full]) :
	                                                        Integer(carrier_data['get_min_prem_response'][:total_premium])
	            else
	              self.tax = Integer(carrier_data['get_min_prem_response'][:tax])
	              self.total_premium = Integer(carrier_data['get_min_prem_response'][:total_premium]) 
	            end
	            
	            if save() && reload()
	              to_return = build_invoice_schedule() ? true : false
	            else
	              # Policy Save Error Block
	              puts "Error".red
	              pp self.errors
	              to_return = false
	            end
		        	
		        else # QBE Response Failure
		        
	            pp qbe_data[:data]
	            to_return = false
		        
		        end # QBE Response Complete
	  
	          if event.save
	            # do nothing
	          else
	            # event failed to save after the request returned
	            pp event.errors
	            to_return = false
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