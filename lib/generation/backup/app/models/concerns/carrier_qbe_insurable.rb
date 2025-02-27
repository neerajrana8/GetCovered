##
# =QBE Insurable Functions Concern
# file: +app/models/concerns/carrier_qbe_insurable.rb+

module CarrierQbeInsurable
  extend ActiveSupport::Concern

  included do
	  
	  # Get QBE Zip Code
	  #
	  # Example:
	  #   @community = Community.find(1)
	  #   @community.get_qbe_zip_code
	  #   => nil
	  
	  def get_qbe_zip_code
	    
	    return if self.insurable_type.title != "Residential Community"
	    @carrier = Carrier.where(title: 'Queensland Business Insurance').take
	    @carrier_profile = carrier_profile(@carrier.id)
	    @address = primary_address()
	    
	    set_error = false
	    
	    unless @address.nil? ||
	           @carrier_profile.data["county_resolved"] == true
	      # When an @address and county resolved
	      event = events.new(
	        verb: 'post', 
	        format: 'xml', 
	        interface: 'SOAP',
	        process: 'qbe_get_zipcode', 
	        endpoint: Rails.application.credentials.qbe[:uri]
	      )
	      
	      return false if @already_in_on_create.nil? == false
	      @already_in_on_create = true
	      
	      qbe_request_timer = {
	        total: nil,
	        start: nil,
	        end: nil
	      }
	      
	      qbe_service = QbeService.new(:action => 'getZipCode')
	      qbe_service.build_request({ prop_zipcode: @address.zip_code })
	      event.request = qbe_service.compiled_rxml  
	      
	      if event.save  
	        # If event saves
	        start_time = Time.now                  
	        
	        qbe_request_timer[:start] = start_time
	        event.started = start_time  
	            
	        # If event saves
	        qbe_data = qbe_service.call()
	        
	        complete_time = Time.now
	        qbe_request_timer[:end] = complete_time 
	        qbe_request_timer[:total] = (complete_time - qbe_request_timer[:start]).to_f
	        event.completed = complete_time
	        
	        event.response = qbe_data[:data]
  	      
	        event.status = qbe_data[:error] ? 'error' : 'success'
	        
	        unless qbe_data[:error] # QBE Response Success
	        		          
	          @carrier_profile.data["county_resolution"]["selected"] = nil
	          @carrier_profile.data["county_resolution"]["results"].clear
	          @carrier_profile.data["county_resolution"]["matches"].clear
	        	
	        	xml_doc = Nokogiri::XML(qbe_data[:data])
	          xml_zip_codes = xml_doc.css("//ZipExtract")

	          # Process QBE_Data
	          if xml_zip_codes.length > 0
	            # There is at least one county
	            @carrier_profile.data["county_resolution"]["available"] = true
	  
	            xml_zip_codes.each do |opt|
	              
	              tmp_opt = {
	                :seq => opt.attributes["seq_no"].value,
	                :locality => opt.attributes["city_name"].value,
	                :county => opt.attributes["county"].value
	              }
	              
	              @carrier_profile.data["county_resolution"]["results"].push(tmp_opt)
	              
	            end
	            
	            @carrier_profile.data["county_resolution"]["matches"] = @carrier_profile.data["county_resolution"]["results"].dup
	            
	            if @address.county.nil?
	              @carrier_profile.data["county_resolution"]["matches"].select! { |opt| opt[:locality] == @address.city }
	            else
	              @carrier_profile.data["county_resolution"]["matches"].select! { |opt| opt[:locality] == @address.city && opt[:county] == @address.county.upcase }        
	            end
	  
	            case @carrier_profile.data["county_resolution"]["matches"].length
	              when 0
	                @carrier_profile.data["county_resolution"]["available"] = false # MOOSE WARNING: this is a temporary answer to the question of how to handle nonempty results with empty matches.
	              when 1
	                @carrier_profile.data["county_resolution"]["selected"] = @carrier_profile.data["county_resolution"]["matches"][0][:seq]
	                @carrier_profile.data["county_resolved"] = true
	                @carrier_profile.data["county_resolved_on"] = Time.current.strftime("%m/%d/%Y %I:%M %p")
	                
	                @address.update_column :county, @carrier_profile.data["county_resolution"]["matches"][0][:county].titlecase
	            end
	            
	            @carrier_profile.save
	           
	          else
	          
	            # No County Listing for ZipCode
	            @carrier_profile.data["county_resolution"]["available"] = false  
	            @carrier_profile.save
	            
	          end
	          # / Process QBE_Data
	        	
	        	# check_carrier_process_error("qbe", false, { process: "get_qbe_zip_code" })
	        	
	        else # QBE Response Failure
	        	
	        	set_error = true
	        	# check_carrier_process_error("qbe", true, { error: qbe_data[:code], process: "get_qbe_zip_code", message: qbe_data[:message] })
	        
	        end # QBE Response Complete
	        
	        if event.save
	          # Event Second Save Success...  
	          # Blank for now
	        else
	          # Event Second Save Failure
	          set_error = true
	          pp event.errors
	        end
	      
	        save()
	        remove_instance_variable(:@already_in_on_create)
	        
	      else
	        # If event does not save
	        set_error = true
	        pp event.errors
	      end
	    else
	      # When an @address or county are not resolved
	      set_error = nil
	    end
	    
	    return set_error
	  end
	  
	  # Get QBE Property Info
	  #
	  # Example:
	  #   >> @community = Community.find(1)
	  #   >> @community.get_qbe_property_info
	  #   => nil
	  
	  def get_qbe_property_info
  	  
	    return if self.insurable_type.title != "Residential Community"
	    @carrier = Carrier.where(title: 'Queensland Business Insurance').take
	    @carrier_profile = carrier_profile(@carrier.id)
	    @address = primary_address()  	  
	    
	    set_error = false
	    
	    if @carrier_profile.data["county_resolved"] == true
	
	      event = events.new(
	        verb: 'post', 
	        format: 'xml', 
	        interface: 'SOAP',
	        process: 'qbe_property_info', 
	        endpoint: Rails.application.credentials.qbe[:uri]
	      )      
	      
	      return false if @already_in_on_create.nil? == false
	      @already_in_on_create = true
	
	      qbe_request_timer = {
	        total: nil,
	        start: nil,
	        end: nil
	      }
	      
	      qbe_service = QbeService.new(:action => 'PropertyInfo')
	      
	      qbe_service.build_request({ prop_number: @address.street_number,
	                                  prop_street: @address.street_name,
	                                  prop_city: @address.city,
	                                  prop_state: @address.state,
	                                  prop_zipcode: @address.zip_code })
	
	      event.request = qbe_service.compiled_rxml
        
#         if Rails.application.credentials.rails_env == "development"
#           puts"\nGet Property Info"
#           puts event.request
#           puts"\n"
#         end
        
	      if event.save
	        # If Event Saves
	        start_time = Time.now                  
	        
	        qbe_request_timer[:start] = start_time
	        event.started = start_time
	        
	        qbe_data = qbe_service.call()
	        
	        complete_time = Time.now
	        qbe_request_timer[:end] = complete_time 
	        qbe_request_timer[:total] = (complete_time - qbe_request_timer[:start]).to_f
	        event.completed = complete_time
	        
	        event.response = qbe_data[:data]
          
	        event.status = qbe_data[:error] ? 'error' : 'success'
	        
	        unless qbe_data[:error] # QBE Response Success
	        	
	        	xml_doc = Nokogiri::XML(qbe_data[:data])
	        		          
	          @carrier_profile.traits['ppc'] = xml_doc.css("PPC_Code").first.content unless xml_doc.css("PPC_Code").first.nil?
	          @carrier_profile.traits['bceg'] = xml_doc.css("BCEG_Code").first.content unless xml_doc.css("BCEG_Code").first.nil?
	        	
	        	@carrier_profile.data["property_info_resolved"] = true
	        	@carrier_profile.data["property_info_resolved_on"] = Time.current.strftime("%m/%d/%Y %I:%M %p")
	        	
	        	@carrier_profile.save()
	        	# check_carrier_process_error("qbe", false, { process: "get_qbe_property_info" })
	        	
	        else # QBE Response Failure
	        	
	        	set_error = true
	        	# check_carrier_process_error("qbe", true, { error: qbe_data[:code], process: "get_qbe_property_info", message: qbe_data[:message] })
	        
	        end # QBE Response Complete
	        
	        if event.save
	          # Event Second Save Success...  
	          # Blank for now
	          # pp event
	        else
	          # Event Second Save Failure
	          set_error = true
	          pp event.errors
	        end
	          
	        save()
	        
	        remove_instance_variable(:@already_in_on_create)
	      else
	        # If Event Does Not Save
	        set_error = true
	        pp event.errors        
	      end
	    else
	      # When an @address or county are not resolved
	      set_error = nil
	    end    
	    
	    return set_error
	  end
  
	  # Fix QBE Carrier Rates
	  
	  def fix_qbe_rates(inline = false)
	    @carrier = Carrier.where(title: 'Queensland Business Insurance').take
	    @carrier_profile = carrier_profile(@carrier.id)
	    
	    if @carrier_profile.data['rates_resolution'].values.include? false
	      broken_rates = []
	      
	      @carrier_profile.data['rates_resolution'].each do |key, value|
	        broken_rates.push(key.to_i) if value == false
	      end
	      
	      broken_rates.each_with_index do |num, index|
		      if inline
						get_qbe_rates(num)		      
			    else
		        # delay = index
		        # GetCommunityRatesJob.set(wait: delay.minutes).perform_later(self, num)  
	        end
	      end
	    end
	  end
	  
	  # Queue QBE Rates
	  #
	  # Example:
	  #   >> @community = Community.find(1)
	  #   >> @community.queue_qbe_rates([1, 2, 3, 4, 5])
	  #   >> true
	  
	  def queue_qbe_rates(insured_options = [])
	    request_errors = {}
	    
	    unless insured_options.empty?
	      
	      # Make sure insured_options are valid 
	      # and unique
	      insured_options = insured_options.uniq
	      insured_options.each do |i|
	        if i.class == Integer &&
	           i > 0 && 
	           i <= 5
	          request_errors["#{i}"] = get_qbe_rates(i) 
	        end
	      end
	      
	    end
	    
	    # return !request_errors.values.include? true
	  end
	  
	  # Reset QBE Carrier Rates
	  
	  def reset_qbe_rates(force = false, inline = false)
	    @carrier = Carrier.where(title: 'Queensland Business Insurance').take
	    @carrier_profile = carrier_profile(@carrier.id)
	    
	    ['1', '2', '3', '4', '5'].each do |key|
	      opt = @carrier_profile.data['rates_resolution'][key]
	      unless opt == false
	        @carrier_profile.data['rates_resolution'][key] = false if force == true
	      end  
	    end
	    # self.ho4_enabled = false
	    
	    save()
	    reload()
	    
	    self.fix_qbe_rates(inline)
	  end

	  # Get QBE Rates
	  #
	  # Example:
	  #   >> @community = Community.find(1)
	  #   >> @community.get_qbe_rates
	  #   => nil
	  
	  def get_qbe_rates(number_insured)
  	  
	    return if self.insurable_type.title != "Residential Community"
	    @carrier = Carrier.where(title: 'Queensland Business Insurance').take
	    @carrier_profile = carrier_profile(@carrier.id)
	    @address = primary_address()  
	    
	    set_error = true
	    
	    process_status = {
	      :error => true,
	      :step => 'start'
	    }
	    
	    unless number_insured.nil? || 
	           @carrier_profile.data["county_resolved"] != true || 
	           @carrier_profile.data["property_info_resolved"] != true
	      # Ready to roll... number_insured is not nil, county is true
	      # and property info has been resolved
	      split_deductible = @address.state == "FL" ? true : false
	      
	      qbe_service = QbeService.new(:action => 'getRates')
	      
	      return false if @already_in_on_create.nil? == false
	      @already_in_on_create = true
	
	      qbe_request_timer = {
	        total: nil,
	        start: nil,
	        end: nil
	      }
	      
	      qbe_request_options = {
	        num_insured: number_insured,
	        prop_city: @address.city,
	        prop_county: @address.county,
	        prop_state: @address.state,
	        prop_zipcode: @address.combined_zip_code,
	        units_on_site: insurables.residential_units.count,
	        age_of_facility: @carrier_profile.traits['construction_year'],
	        ppc: @carrier_profile.traits['ppc'],
	        bceg: @carrier_profile.traits['bceg'],
	        protection_device_code: @carrier_profile.traits['protection_device_cd'],
	        constr_type: @carrier_profile.traits['construction_type'],
	        gated_community: @carrier_profile.traits['gated_access'] == true ? 1 : 0,
	        prof_managed: @carrier_profile.traits['professionally_managed'] == true ? 1 : 0,
	        prof_managed_year: @carrier_profile.traits['professionally_managed_year'].nil? ? "" : @carrier_profile.traits['professionally_managed_year']
	      }
	      
	      qbe_service.build_request(qbe_request_options)
	            
	      event = events.new(
	        verb: 'post', 
	        format: 'xml', 
	        interface: 'SOAP',
	        process: 'get_qbe_rates',
	        request: qbe_service.compiled_rxml,
	        endpoint: Rails.application.credentials.qbe[:uri]
	      )
	
	      if event.save
	        # If Event Saves
	        # toggle_background_job(true, "get_community_rates_#{ number_insured }")
	        start_time = Time.now                  
	        
	        qbe_request_timer[:start] = start_time
	        event.started = start_time
	        
	        qbe_data = qbe_service.call()
	        
	        complete_time = Time.now
	        qbe_request_timer[:end] = complete_time 
	        qbe_request_timer[:total] = (complete_time - qbe_request_timer[:start]).to_f
	        event.completed = complete_time
	        
# 	        self.carrier_settings["qbe"]["api_metrics"]["get_rates"].push({
# 	          duration: "%.4f" % qbe_request_timer[:total],
# 	          date_time: Time.current.iso8601(9)
# 	        })
	        
	        event.response = qbe_data[:data]
	        event.status = qbe_data[:error] ? 'error' : 'success'
	        
	        unless qbe_data[:error] # QBE Response Success
	          
	          set_error = false
	          
	          if create_qbe_rates(qbe_data[:data], split_deductible, number_insured)
		          
	            @carrier_profile.data['rates_resolution']["#{ number_insured }"] = true
	            
	            unless @carrier_profile.data['rates_resolution'].values.include? false
	              @carrier_profile.data["ho4_enabled"] = true
	              @carrier_profile.data["get_rates_resolved"] = true 
	              @carrier_profile.data["get_rates_resolved_on"] = Time.current.strftime("%m/%d/%Y %I:%M %p")
	            end
	            
	            insurable_rates.activated
	                 					 .where("created_at < ? and number_insured = ?", start_time, number_insured)
									 					 .update_all(:activated => false)            
	            
	            process_status[:error] = false
	            
							#check_carrier_process_error("qbe", false, { process: "get_qbe_rates_#{ number_insured }" })
	          else
	          
	            rates.activated
	                 .where(number_insured: number_insured)
	                 .update_all(:activated => false)
	                 
	            set_error = true
	            @carrier_profile.data["get_rates_resolved"] = false 
							# check_carrier_process_error("qbe", true, { error: qbe_data[:code], process: "get_qbe_rates_#{ number_insured }", message: qbe_data[:message] }) 
							@carrier_profile.save()
	          end
	        	
	        else # QBE Response Failure
	        	
	          # QBE Reqeust Error
	          set_error = true
	          process_status[:error] = true
	          process_status[:step] = 'request_qbe_rates'
	          #self.report_rate_failure("#{ name } Rate Request Failure.  #{number_insured} Insured", "QBE DATA: \n#{ qbe_data[:data] }")
	        	#check_carrier_process_error("qbe", true, { error: qbe_data[:code], process: "get_qbe_rates_#{ number_insured }", message: qbe_data[:message] })
	        
	        end # QBE Response Complete       
	        
	        if event.save
	          # Blank for now....
	        else
	          # Event Second Save Failure
	          pp event.errors
	          # self.report_rate_failure("#{ name } Rate Sync Failure", "A rate has failed to sync \n#{ event.errors.to_json.to_s }")
	        end
	          
	        save()
	        
	        remove_instance_variable(:@already_in_on_create)
	        # toggle_background_job(false, "get_community_rates_#{ number_insured }")
	      end          
	    end
	    
	    # return bool inverse of process_status[:error], 
	    # true for success, false for failure
	    return process_status[:error] == true ? false : true
	  end
	  
	  # Create QBE Rates
	  #
	  # Params:
	  # +response_arr+:: (Array) []
	  # +split_deductible+:: (Boolean) false
	  #
	  # Example:
	  #   >> @community = Community.find(1)
	  #   >> @community.create_qbe_rates(arr)
	  #   => true : false
	  
	  def create_qbe_rates(qbe_data = nil, split_deductible = false, num_base = 1)
  	  
	    return if self.insurable_type.title != "Residential Community"
	    @carrier = Carrier.where(title: 'Queensland Business Insurance').take
	    @carrier_profile = carrier_profile(@carrier.id)
	    
	    set_error = true
	    
	    process_status = {
	      :error => true,
	      :step => 'start'
	    }
	    
	    unless qbe_data.nil?
	      qbe = Carrier.where(:title => "QBE").first
	      unless qbe_data.class == Hash && 
	             qbe_data.key?(:error) && 
	             qbe_data.key?(:error) == true
	             
	        coverage_schedules = []
	        
	        xml_doc = Nokogiri::XML(qbe_data)
	        xml_coverage_schedules = xml_doc.css('//c') 
	                      
	        xml_coverage_schedules.each do |cv|
	          ["m", "cov"].each do |sub_schedule|
	            cv.css(sub_schedule).each do |qbe_rate|
	              # Build Rates Start
	              
	              unless qbe_rate.attributes["i"].nil?
	                schedule = nil
	                sub_schedule = nil
	                paid_in_full = false
	                same_price_across_the_board = false
	                
	                coverage_limits = {}
	                
	                unless qbe_rate.attributes["covclimit"].nil?
	                  coverage_limits["coverage_c"] = qbe_rate.attributes["covclimit"].value.to_i * 100
	                end
	                
	                unless qbe_rate.attributes["liablimit"].nil?
	                  coverage_limits["liability"] = qbe_rate.attributes["liablimit"].value.to_i * 100
	                end
	                
	                unless qbe_rate.attributes["medpaylimit"].nil?
	                  coverage_limits["medical"] = qbe_rate.attributes["medpaylimit"].value.to_i * 100
	                end
	                
	                base_deductible_value = qbe_rate.attributes["deduct_amt"].nil? ? "0" : qbe_rate.attributes["deduct_amt"].value
	                
	                deductibles = {}
	                
	                if split_deductible == true # if deductible needs to be split for florida
	                  if base_deductible_value.include? "/" # if the the deductible includes a /, indicating a split must occur
	                    split_deductibles = base_deductible_value.split("/")
	                    
	                    deductibles["all_peril"] = split_deductibles[0].to_i * 100
	                    deductibles["hurricane"] = split_deductibles[1].to_i * 100
	                    
	                  else # if the deductible is 0
	                    deductibles["all_peril"] = base_deductible_value.to_i * 100                    
	                  end
	                else # if the deductible does not need to be split, e.g. not florida
	                  deductibles["all_peril"] = base_deductible_value.to_i * 100                   
	                end
	                                
	                raw_schedule = qbe_rate.attributes["i"].value
	                interval = "month"
	                liability_only = false
	                
	                if raw_schedule =~ /cov_base_premium|cov_base_premium_pay_in_full/
	                  schedule = "coverage_c"
	                  paid_in_full = raw_schedule == "cov_base_premium_pay_in_full" ? true : false
	                  interval = "year" if paid_in_full == true
	                  
	                elsif raw_schedule == "liability_premium"
	                  schedule = "liability"
	                  same_price_across_the_board = true
	                  
	                elsif raw_schedule =~ /liabilityonly_premium|liabilityonly_premium_pay_in_full/
	                  schedule = "liability_only"
	                  paid_in_full = raw_schedule == "liabilityonly_premium_pay_in_full" ? true : false
	                  interval = "year" if paid_in_full == true
	                  liability_only = true
	                  
	                elsif raw_schedule =~ /water_backup|pet_damage|policy_fee|earthquake_coverage|bedbug|equip/
	                  schedule = "optional"
	                  sub_schedule = raw_schedule
	                  same_price_across_the_board = true
	                end
	
	                
	                if paid_in_full
	                  
	                  rate = self.insurable_rates.new(
	                    :schedule => schedule,
	                    :sub_schedule => sub_schedule,
	                    :paid_in_full => paid_in_full,
	                    :liability_only => liability_only,
	                    :interval => interval,
	                    :premium => (qbe_rate.attributes["v"].value.to_i * 100),
	                    :number_insured => num_base,
	                    :deductibles => deductibles,
	                    :coverage_limits => coverage_limits,
                      :carrier => @carrier,
                      :agency => account.agency,
	                    :activated => true
	                  )
	                  
	                  if rate.save
	                    set_error = false          
	                    process_status[:error] = false
	                  else
	                    
	                    set_error = true
	                    process_status[:error] = true
	                    process_status[:step] = 'create_rate_paid_in_full'                    
	                    pp rate.errors
	                    
	                    self.staff.each do |staff|
	                      notifications.create!(
	                          notifiable: staff, 
	                          action: "community_rates_sync",
	                          code: "error",
	                          subject: "#{ name } Rate Sync Failure", 
	                          message: "A rate has failed to sync \n#{ rate.errors.to_json.to_s }")                        
	                    end
	                  end
	                  
	                else
	                  interval_options = ["month", "quarter_year", "half_year"]
	                  interval_options.push('year') if same_price_across_the_board || split_deductible == true
	                  
	                  interval_options.each do |cur_interval|
	                    
	                    rate = self.insurable_rates.new(
	                      :schedule => schedule,
	                      :sub_schedule => sub_schedule,
	                      :paid_in_full => cur_interval == "year" ? true : false,
	                      :liability_only => liability_only,
	                      :interval => cur_interval,
	                      :premium => (qbe_rate.attributes["v"].value.to_i * 100),
	                      :number_insured => num_base,
	                      :deductibles => deductibles,
	                      :coverage_limits => coverage_limits,
	                      :carrier => @carrier,
	                      :agency => account.agency,
	                      :activated => true
	                    )
	                    
	                    if rate.save
	                      set_error = false
	                      process_status[:error] = false
	                    else
	                      set_error = true
	                      process_status[:error] = true
	                      process_status[:step] = "create_rate_#{ rate.interval }" 
	                      pp rate.errors
	                      
	                      self.report_rate_failure("#{ name } Rate Sync Failure", "A rate has failed to sync \n#{ rate.errors.to_json.to_s }")
	                      
	                    end
	                    
	                  end
	                end
	                
	              else
	              
	                puts "\nRATE ERROR\n"
	                pp qbe_rate
	                set_error = true
	                process_status[:error] = true
	                process_status[:step] = "qbe_rates_loop" 
	                
	                self.report_rate_failure("#{ name } Rate Sync Failure", "A rate has failed to sync \n#{ rate.errors.to_json.to_s }")
	                
	              end
	              
	              # Build Rates End
	            end
	          end
	        end
	        
	      else
	        
	        # Uh Oh! 
	        # Qbe Error
	        puts "Uh Oh Spegettio"
	        set_error = true
	        process_status[:error] = true
	        process_status[:step] = "qbe_rates_loop" 
	        
	        self.report_rate_failure("#{ name } Rate Sync Failure", "A rate has failed to sync \n#{ rate.errors.to_json.to_s }")
	        
	      end      
	    end
	    
	    # return bool inverse of process_status[:error], 
	    # true for success, false for failure
	    return process_status[:error] == true ? false : true
	  end

	  def update_county_data(county_number_string)
	    if self.carrier_settings['qbe']['county_resolved']
	      self.errors.add(:county, "the community already has a county")
	      return nil
	    elsif !(self.carrier_settings['qbe']['county_resolution']['available'] && self.carrier_settings['qbe'] && self.carrier_settings['qbe']['county_resolution'] && !self.carrier_settings['qbe']['county_resolution']['matches'].blank?)
	      self.errors.add(:county, "there is no coverage available for the selected county")
	      return nil
	    end
	    self.carrier_settings['qbe']['county_resolution']['matches'].each do |county_option|
	      if county_option['seq'] == county_number_string
	        found = true
	        self.carrier_settings['qbe']['county_resolution']['selected'] = county_number_string
	        self.carrier_settings['qbe']['county_resolved_on'] = Time.current
	        self.carrier_settings['qbe']['county_resolved'] = true
	        return count_option['county'].titlecase
	      end
	    end
	    self.errors.add(:county, "the selected county was not found")
	    return nil
	  end
	
	  def reresolve_county_data
	    get_qbe_zip_code
	  end

	  # Set Carrier Process Error
	  #
	  # Arguments for error:
	  #   carrier_slug: (String)
	  #   set_error: (boolean)
	  #   args: (Hash)
	  #   args[:process]: (String)
	  #   args[:error]: (String)
	  #   args[:message]: (String)
	  #
	  # Arguments to clear error:
	  #   carrier_slug: (String)
	  #   set_error: (boolean)
	  #   args: (Hash)
	  #   args[:process]: (String)
	  #
	  # Example:
	  #   @community = Community.find(1)
	  #   @community.check_carrier_process_error("qbe", true, args)
	  #   => true
	  #   @community.check_carrier_process_error("qbe", false, args)
	  #   => true
	  
	  def check_carrier_process_error(carrier_slug = "qbe", set_error = false, args = nil)
	    
	    if set_error == true
	      
	      options = {
	        process:  nil,
	        error:    nil,
	        datetime: Time.current
	      }.merge!(args)
	      
	      self.carrier_settings[carrier_slug]["process_error"] = true
	      self.carrier_settings[carrier_slug]["process_error_open"].push(options)
	      
	      self.carrier_error_list << carrier_slug
	      self.carrier_error = true
	      
	    else
	      
	      options = {
	        process:  nil
	      }.merge!(args)
	      
	      self.carrier_settings[carrier_slug]["process_error_open"].delete_if { |err| err["process"] == options[:process] } unless options[:process].nil?
	      
	      if carrier_settings[carrier_slug]["process_error_open"].length == 0
	    
	        delete_index = carrier_error_list.index { |x| x == carrier_slug }
	      
	        self.carrier_settings[carrier_slug]["process_error"] = false 
	        self.carrier_error_list.delete_at(delete_index) unless delete_index.nil?
	        self.carrier_error = false
	      end  
	      
	    end
	    
	    save()
	    
	  end
	  
	end
end