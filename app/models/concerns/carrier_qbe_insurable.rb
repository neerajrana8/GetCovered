##
# =QBE Insurable Functions Concern
# file: +app/models/concerns/carrier_qbe_insurable.rb+

module CarrierQbeInsurable
  extend ActiveSupport::Concern

  included do
  
    def qbe_get_carrier_status(refresh: false)
      @qbe_get_carrier_status = nil if refresh
      return @qbe_get_carrier_status ||= !::InsurableType::RESIDENTIAL_IDS.include?(self.insurable_type_id) ?
        nil
        : (self.confirmed && self.parent_community&.carrier_profile(::QbeService.carrier_id)&.traits&.[]('pref_facility') == 'MDU' ? :preferred : :nonpreferred) # WARNING: change this at some point in case we confirm nonpreferred properties?
    end
    
    def qbe_mark_preferred(strict: false, apply_defaults: !strict)
      return "The insurable is not a community" unless ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS.include?(self.insurable_type_id)
      return "The insurable has a 'confirmed' value of false; it must be assigned to an account and marked as confirmed before being registered as preferred" unless self.confirmed
      cp = self.carrier_profile(::QbeService.carrier_id)
      if cp.nil?
        if strict
          return "The community has no CarrierInsurableProfile for QBE"
        else
          self.create_carrier_profile(::QbeService.carrier_id)
          cp = self.carrier_profile(::QbeService.carrier_id)
        end
      end
      cp.traits['pref_facility'] = 'MDU'
      if apply_defaults
        cp.traits['occupancy_type'] ||= 'Other'
        cp.traits['construction_type'] ||= 'F'
        cp.traits['protection_device_cd'] ||= 'F'
        cp.traits['alarm_credit'] = false if cp.traits['alarm_credit'].nil?
        cp.traits['professionally_managed'] = true
        cp.traits['professionally_managed_year'] ||= 2015
        cp.traits['construction_year'] ||= 1996
        cp.traits['gated'] = false if cp.traits['gated'].nil?
        cp.traits['city_limit'] = true if cp.traits['city_limit'].nil?
      end
      unless cp.save
        return "The modified preferred status failed to save"
      end
      self.update(preferred_ho4: true)
      self.buildings.confirmed.update_all(preferred_ho4: true)
      self.units.confirmed.update_all(preferred_ho4: true)
      FetchQbeRatesJob.perform_later(self)
      return nil
    end
	  
	  # Get QBE Zip Code
	  #
	  # Example:
	  #   @community = Community.find(1)
	  #   @community.get_qbe_zip_code
	  #   => nil
	  
	  def get_qbe_zip_code
	    
	    return if self.insurable_type.title != "Residential Community"
	    @carrier = ::QbeService.carrier
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
	        endpoint: Rails.application.credentials.qbe[:uri][ENV["RAILS_ENV"].to_sym]
	      )
	      
	      return false if @already_in_on_create.nil? == false
	      @already_in_on_create = true
	      
	      qbe_request_timer = {
	        total: nil,
	        start: nil,
	        end: nil
	      }
	      
	      carrier_agency = CarrierAgency.where(agency_id: agency_id || account&.agency_id || Agency::GET_COVERED_ID, carrier: @carrier).take
	      
	      qbe_service = QbeService.new(:action => 'getZipCode')
	      qbe_service.build_request({ prop_zipcode: @address.zip_code, agent_code: carrier_agency.get_agent_code })
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
	                'seq' => opt.attributes["seq_no"].value,
	                'locality' => opt.attributes["city_name"].value,
	                'county' => opt.attributes["county"].value
	              }
	              
	              @carrier_profile.data["county_resolution"]["results"].push(tmp_opt)
	              
	            end
	            
	            @carrier_profile.data["county_resolution"]["matches"] = @carrier_profile.data["county_resolution"]["results"].dup              
	            
              # if address has no county, restrict by city and try to get the county if necessary
	            if @address.county.nil?
	              @carrier_profile.data["county_resolution"]["matches"].select! { |opt| opt['locality'].downcase == @address.city.downcase || opt['locality'].downcase == @address.neighborhood&.downcase }
                if @carrier_profile.data["county_resolution"]["matches"].length > 1
                  @address.geocode if @address.latitude.blank?
                  unless @address.latitude.blank?
                    @address.send(:get_county_from_fcc)
                    @address.save unless @address.county.blank?
                  end
                end
              end

              # if address has a county, restrict by it
	            if !@address.county.nil?
	              @carrier_profile.data["county_resolution"]["matches"].select! { |opt| (opt['locality'].downcase == @address.city.downcase || opt['locality'].downcase == @address.neighborhood&.downcase) && qbe_standardize_county_string(opt['county']) == qbe_standardize_county_string(@address.county) } # just in case one is "Whatever County" and the other is just "Whatever", one has a dash and one doesn't, etc
	            end
              
              if @carrier_profile.data['county_resolution']['matches'].count{|opt| opt['locality'].downcase == @address.city.downcase } == 1 && @carrier_profile.data['county_resolution']['matches'].count{|opt| opt['locality'].downcase == @address.neighborhood&.downcase } == 1
                @carrier_profile.data['county_resolution']['matches'].select!{|opt| opt['locality'].downcase == @address.neighborhood&.downcase }
              end
	  
	            case @carrier_profile.data["county_resolution"]["matches"].length
	              when 0
	                @carrier_profile.data["county_resolution"]["available"] = false # WARNING: this is a temporary answer to the question of how to handle nonempty results with empty matches: we just treat them as if no county info came down at all. this will cause this process to be rerun too, which may be good
	              when 1
	                @carrier_profile.data["county_resolution"]["selected"] = @carrier_profile.data["county_resolution"]["matches"][0]['seq']
	                @carrier_profile.data["county_resolved"] = true
	                @carrier_profile.data["county_resolved_on"] = Time.current.strftime("%m/%d/%Y %I:%M %p")
	                
	                @address.update_column :county, @carrier_profile.data["county_resolution"]["matches"][0]['county'].downcase.titlecase
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
	    
	    return set_error ? false : true
	  end
	  
	  # Get QBE Property Info
	  #
	  # Example:
	  #   >> @community = Community.find(1)
	  #   >> @community.get_qbe_property_info
	  #   => nil
	  
	  def get_qbe_property_info
  	  
	    return if self.insurable_type.title != "Residential Community"
	    @carrier = ::QbeService.carrier
	    @carrier_profile = carrier_profile(@carrier.id)
	    @address = primary_address()  	  
	    
	    set_error = false
	    
	    if @carrier_profile.data["county_resolved"] == true
	
	      event = events.new(
	        verb: 'post', 
	        format: 'xml', 
	        interface: 'SOAP',
	        process: 'qbe_property_info', 
	        endpoint: Rails.application.credentials.qbe[:uri][ENV["RAILS_ENV"].to_sym]
	      )      
	      
	      return false if @already_in_on_create.nil? == false
	      @already_in_on_create = true
	
	      qbe_request_timer = {
	        total: nil,
	        start: nil,
	        end: nil
	      }
	      
	      qbe_service = QbeService.new(:action => 'PropertyInfo')
	      carrier_agency = CarrierAgency.where(agency_id: agency_id || account&.agency_id || Agency::GET_COVERED_ID, carrier: @carrier).take
        city = @carrier_profile.data&.[]("county_resolution")&.[]("matches")&.find{|m| m["seq"] == @carrier_profile.data["county_resolution"]["selected"] }&.[]("locality") || @address.city
	      
	      qbe_service.build_request({ prop_number: @address.street_number,
	                                  prop_street: @address.street_name,
	                                  prop_city: city,
	                                  prop_state: @address.state,
	                                  prop_zipcode: @address.zip_code, 
	                                  agent_code: carrier_agency.get_agent_code })
	
	      event.request = qbe_service.compiled_rxml
        
#         if ENV['RAILS_ENV'].to_sym == "development"
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
            # this is disabled; everything defaults to FIC on CIP creation, we manually set some to MDU later @carrier_profile.traits['pref_facility'] = (self.confirmed &&  ? 'MDU' : 'FIC') 
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
	    
	    return set_error ? false : true
	  end
  
	  # Fix QBE Carrier Rates
	  
	  def fix_qbe_rates(inline = false, effective_date = nil, traits_override: {}, delay: 1)
	    @carrier = ::QbeService.carrier
	    @carrier_profile = carrier_profile(@carrier.id)
	    
	    if @carrier_profile.data['rates_resolution'].values.include? false
	      broken_rates = []
	      
	      @carrier_profile.data['rates_resolution'].each do |key, value|
	        broken_rates.push(key.to_i) if value == false
	      end
	      
        if inline
          broken_rates.each{|br| get_qbe_rates(br, effective_date, traits_override: traits_override) }
        else
          FetchQbeRatesJob.perform_later(self, number_insured: broken_rates, effective_date: effective_date, traits_override: traits_override, delay: delay)
        end
	    end
	  end
	  
	  # Reset QBE Carrier Rates
	  
	  def reset_qbe_rates(force = false, inline = false, traits_override: {})
	    @carrier = ::QbeService.carrier
	    @carrier_profile = carrier_profile(@carrier.id)
	    
	    ['1', '2', '3', '4', '5'].each do |key|
	      opt = @carrier_profile.data['rates_resolution'][key]
	      unless opt == false
	        @carrier_profile.data['rates_resolution'][key] = false if force == true
	      end  
	    end
      @carrier_profile.data["ho4_enabled"] = false
      @carrier_profile.save
      self.fix_qbe_rates(inline, traits_override: traits_override)
	  end

	  # Get QBE Rates
	  #
	  # Example:
	  #   >> @community = Community.find(1)
	  #   >> @community.get_qbe_rates
	  #   => nil
	  # Passing refresh_coverage_options: true will reset the coverage options in the community's IRC regardless of whether they're already set (as opposed to just resetting the rates);
    # Passing traits_override allows custom overrides to the request options normally derived from the community's CIP (useful for FIC properties where the CIP is empty and we need to apply defaults from the policy application);
    # Passing diagnostics_hash as a hash will cause diagnostic info to be inserted into it (since the return value is set up to indicate success via a boolean, we can't use it to return information)
    #   - the only diagnostic returned right now is diagnostics_hash[:event] = the event recording the getRates call
    # Passing irc_configurable_override will cause an IRC to be created for a DIFFERENT configurable, rather than this insurable. This is used to create IRCs for IGCs for rate caching, since the IGC rates are calculated with fixed parameters that may not match those of its sample insurable.
	  def get_qbe_rates(number_insured, effective_date = nil, refresh_coverage_options: false, traits_override: nil, diagnostics_hash: nil, irc_configurable_override: nil)
  	  
	    return if self.insurable_type.title != "Residential Community"
	    @carrier = ::QbeService.carrier
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
	      
        
	      carrier_agency = CarrierAgency.where(agency_id: agency_id || account&.agency_id || Agency::GET_COVERED_ID, carrier: @carrier).take
        carrier_policy_type = CarrierPolicyType.where(carrier: @carrier, policy_type_id: ::PolicyType::RESIDENTIAL_ID).take
        city = @carrier_profile.data&.[]("county_resolution")&.[]("matches")&.find{|m| m["seq"] == @carrier_profile.data["county_resolution"]["selected"] }&.[]("locality") || @address.city
        county = @carrier_profile.data&.[]("county_resolution")&.[]("matches")&.find{|m| m["seq"] == @carrier_profile.data["county_resolution"]["selected"] }&.[]("county") || @address.county # we use the QBE formatted one in case .titlecase killed dashes etc.
        carrier_status = self.get_carrier_status(@carrier)
        full_traits_override = self.get_qbe_traits().merge(traits_override || {})
        applicability = QbeService.get_applicability(self, full_traits_override, cip: @carrier_profile)
      
        
	      qbe_request_options = {
          pref_facility: (carrier_status == :preferred ? 'MDU' : 'FIC'),
	        prop_city: city,
	        prop_county: county,
	        prop_state: @address.state,
	        prop_zipcode: @address.combined_zip_code,
          # The commented out properties all come from get_qbe_traits
	        #units_on_site: units.confirmed.count,
	        #age_of_facility: @carrier_profile.traits['construction_year'],
	        #gated_community: @carrier_profile.traits['gated_access'] == true ? 1 : 0,
	        #prof_managed: @carrier_profile.traits['professionally_managed'] == true ? 1 : 0,
	        #prof_managed_year: @carrier_profile.traits['professionally_managed_year'].nil? ? "" : @carrier_profile.traits['professionally_managed_year'],
	        num_insured: number_insured,
	        protection_device_code: @carrier_profile.traits['protection_device_cd'],
	        constr_type: @carrier_profile.traits['construction_type'],
	        ppc_code: @carrier_profile.traits['ppc'],
	        bceg_code: @carrier_profile.traits['bceg'],
	        agent_code: carrier_agency.get_agent_code,
          effective_date: (effective_date || (Time.current.to_date + 1.day)).strftime('%m/%d/%Y')
	      }.merge(full_traits_override)
	      
# 	      qbe_request_options = {
# 	        num_insured: number_insured,
# 	        prop_city: @address.city,
# 	        prop_county: @address.county,
# 	        prop_state: @address.state,
# 	        prop_zipcode: @address.combined_zip_code,
# 	        units_on_site: units.count,
# 	        age_of_facility: @carrier_profile.traits['construction_year'],
# 	        ppc_code: @carrier_profile.traits['ppc'],
# 	        bceg: @carrier_profile.traits['bceg'],
# 	        protection_device_code: @carrier_profile.traits['protection_device_cd'],
# 	        constr_type: @carrier_profile.traits['construction_type'],
# 	        gated_community: @carrier_profile.traits['gated_access'] == true ? 1 : 0,
# 	        prof_managed: @carrier_profile.traits['professionally_managed'] == true ? 1 : 0,
# 	        prof_managed_year: @carrier_profile.traits['professionally_managed_year'].nil? ? "" : @carrier_profile.traits['professionally_managed_year'], 
# 	        agent_code: carrier_agency.get_agent_code
# 	      }
	      
	      qbe_service.build_request(qbe_request_options)
	            
	      event = Event.new(
          eventable: irc_configurable_override || self,
	        verb: 'post', 
	        format: 'xml', 
	        interface: 'SOAP',
	        process: 'get_qbe_rates',
	        request: qbe_service.compiled_rxml,
	        endpoint: Rails.application.credentials.qbe[:uri][ENV["RAILS_ENV"].to_sym]
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
          
          diagnostics_hash[:event] = event if diagnostics_hash.class == ::Hash
	        
	        unless qbe_data[:error] # QBE Response Success
	          
	          set_error = false
	          
            rates = create_qbe_rates(qbe_data[:data], split_deductible, number_insured)
            
            irc = ::InsurableRateConfiguration.where(carrier_policy_type: carrier_policy_type, configurer: @carrier, configurable: irc_configurable_override || self)
                .find{|irc| irc_configurable_override || irc.rates['applicability'] == applicability } || ::InsurableRateConfiguration.new(
              carrier_policy_type: carrier_policy_type,
              configurer: @carrier,
              configurable: irc_configurable_override || self,
              configuration: { 'coverage_options' => {}, "rules" => {} },
              rates: { 'rates' => [nil, {}, {}, {}, {}, {}] }
            )
            irc.rates['applicability'] = applicability unless irc_configurable_override
            
	          if rates
		          
	            @carrier_profile.data['rates_resolution']["#{ number_insured }"] = true
              @carrier_profile.data["ho4_enabled"] = true # as long as we have rates for at least one number_insured choice, we say true now
	            
	            unless @carrier_profile.data['rates_resolution'].values.include? false
	              @carrier_profile.data["get_rates_resolved"] = true 
	              @carrier_profile.data["get_rates_resolved_on"] = Time.current.strftime("%m/%d/%Y %I:%M %p")
	            end
	            @carrier_profile.save() unless irc_configurable_override
              
              irc.rates['rates'][number_insured] = rates      
	            
	            process_status[:error] = false
	            
							#check_carrier_process_error("qbe", false, { process: "get_qbe_rates_#{ number_insured }" })
              if refresh_coverage_options || irc.configuration['coverage_options'].blank?
                irc.configuration['coverage_options'] = qbe_extract_coverage_options_from_rates(rates.values.first) # options are the same for all number insured/billing strategy combos, supposedly
              end
              unless irc.save
                set_error = true
                puts "IRC FAILURE #{irc.errors.to_h}"
                irc.rates['rates'][number_insured] = {}
                irc.configuration['coverage_options'] = {} if irc.rates['rates'].compact.all?{|rate_hash| rate_hash.values.all?{|v| v.blank? } }
                set_error = true
                @carrier_profile.data["get_rates_resolved"] = false 
                irc.save
              end
	          else
            
              irc.rates['rates'][number_insured] = {}
              irc.configuration['coverage_options'] = {} if irc.rates['rates'].compact.all?{|rate_hash| rate_hash.values.all?{|v| v.blank? } }
	                 
	            set_error = true
	            @carrier_profile.data["get_rates_resolved"] = false 
							# check_carrier_process_error("qbe", true, { error: qbe_data[:code], process: "get_qbe_rates_#{ number_insured }", message: qbe_data[:message] }) 
							@carrier_profile.save() unless irc_configurable_override
              irc.save
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
    
    # Extracts IRC coverage options hash from rates array
    def qbe_extract_coverage_options_from_rates(rates)
      # grab the options
      limopts = {}
      dedopts = {}
      optionals = {}
      rates.each do |r|
        if r['schedule'] == 'optional'
          unless r['sub_schedule'] == 'policy_fee'
            optionals[r['sub_schedule']] ||= []
            optionals[r['sub_schedule']].push(r['individual_limit']) unless optionals[r['sub_schedule']].include?(r['individual_limit'])
          end
        else
          r['coverage_limits'].each{|cov,amt| limopts[cov] ||= []; limopts[cov].push(amt) unless limopts[cov].include?(amt) }
          r['deductibles'].each{|cov,amt| dedopts[cov] ||= []; dedopts[cov].push(amt) unless dedopts[cov].include?(amt) }
        end
      end
      limopts.each{|k,v| v.sort! }
      dedopts.each{|k,v| v.sort! }
      # build the proper coverage options hash
      coverage_options = (limopts.map do |name, options|
        [
          name,
          {
            'title' => name.titlecase, # This may not produce an optimal name. But it doesn't ever produce a name that isn't clear, and the translation files are used for displaying names to customers.
            'visible' => true,
            'requirement' => 'required',
            'options_type' => 'multiple_choice',
            'options' => options.map{|opt| { 'data_type' => 'currency', 'value' => opt } },
            'category' => 'limit'
          }
        ]
      end + dedopts.map do |name, options|
        [
          name,
          {
            'title' => name.titlecase,
            'visible' => true,
            'requirement' => 'required',
            'options_type' => 'multiple_choice',
            'options' => options.map{|opt| { 'data_type' => 'currency', 'value' => opt } },
            'category' => 'deductible'
          }
        ]
      end + optionals.map do |name, options|
        ot = (options.length == 0 || (options.length == 1 && options.first == 0)) ? 'none' : 'multiple_choice'
        [
          name,
          {
            'title' => name.titlecase,
            'visible' => true,
            'requirement' => 'optional',
            'options_type' => ot,
            'options' => (ot == 'none' ? nil : options.map{|opt| { 'data_type' => 'currency', 'value' => opt } }),
            'category' => (ot == 'none' ? 'option' : 'limit')
          }.compact
        ]
      end).to_h
      # deduce any necessary rules
      # WARNING: no need to do this, supposedly, but maybe implement at some point?
      # (the idea would be to look for combinations of rates that aren't in QBE's list, and dynamically generate IRC rules forbidding them; but in theory every combination is permitted, so we don't do this right now)
      # done
      return coverage_options
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
	    @carrier = ::QbeService.carrier
	    @carrier_profile = carrier_profile(@carrier.id)
	    
	    set_error = true
	    
	    process_status = {
	      :error => true,
	      :step => 'start'
	    }
      
      rates = {}
	    
	    unless qbe_data.nil?
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
	                  coverage_limits["coverage_c"] = (qbe_rate.attributes["covclimit"].value.delete(',').to_d * 100).to_i
	                end
	                
	                unless qbe_rate.attributes["liablimit"].nil?
	                  coverage_limits["liability"] = (qbe_rate.attributes["liablimit"].value.delete(',').to_d * 100).to_i
	                end
	                
	                unless qbe_rate.attributes["medpaylimit"].nil?
	                  coverage_limits["medical"] = (qbe_rate.attributes["medpaylimit"].value.delete(',').to_d * 100).to_i
	                end
	                
	                base_deductible_value = qbe_rate.attributes["deduct_amt"].nil? ? "0" : qbe_rate.attributes["deduct_amt"].value.delete(',')
	                
	                deductibles = {}
	                
	                if split_deductible == true # if deductible needs to be split for florida
	                  if base_deductible_value.include? "/" # if the the deductible includes a /, indicating a split must occur
	                    split_deductibles = base_deductible_value.split("/")
	                    
	                    deductibles["all_peril"] = (split_deductibles[0].delete(',').to_d * 100).to_i
	                    deductibles["hurricane"] = (split_deductibles[1].delete(',').to_d * 100).to_i
	                    
	                  else # if the deductible is 0
	                    deductibles["all_peril"] = (base_deductible_value.delete(',').to_d * 100).to_i                   
	                  end
	                else # if the deductible does not need to be split, e.g. not florida
	                  deductibles["all_peril"] = (base_deductible_value.delete(',').to_d * 100).to_i                   
	                end
                  
                  coverage_limits.select!{|k,v| v != 0 }
                  deductibles.select!{|k,v| v != 0 }
	                                
	                raw_schedule = qbe_rate.attributes["i"].value
	                interval = "month"
	                liability_only = false
	                
	                if raw_schedule =~ /cov_base_premium|cov_base_premium_pay_in_full/
	                  schedule = "coverage_c"
	                  paid_in_full = raw_schedule == "cov_base_premium_pay_in_full" ? true : false
	                  interval = "annual" if paid_in_full == true
	                  
	                elsif raw_schedule == "liability_premium"
	                  schedule = "liability"
	                  same_price_across_the_board = true
	                  
	                elsif raw_schedule =~ /liabilityonly_premium|liabilityonly_premium_pay_in_full/
	                  schedule = "liability_only"
	                  paid_in_full = raw_schedule == "liabilityonly_premium_pay_in_full" ? true : false
	                  interval = "annual" if paid_in_full == true
	                  liability_only = true
	                  
	                elsif raw_schedule =~ /water_backup|pet_damage|policy_fee|earthquake_coverage|bedbug|equip/
	                  schedule = "optional"
	                  sub_schedule = raw_schedule
	                  same_price_across_the_board = true
                  else
                    next
	                end
	
	                
	                if paid_in_full
                  
                    rates[interval] ||= []
                    rates[interval].push({
                      'schedule' => schedule,
                      'sub_schedule' => sub_schedule,
                      'paid_in_full' => paid_in_full,
                      'liability_only' => liability_only,
                      'premium' => (qbe_rate.attributes["v"].value.delete(',').to_d * 100).to_i,
                      'deductibles' => deductibles,
                      'coverage_limits' => coverage_limits,
                      'individual_limit' => ((qbe_rate.attributes["indvllimit"]&.value&.delete(',') || 0).to_d * 100).to_i
                    })
                    
                    set_error = false          
                    process_status[:error] = false
	                  
	                else
	                  interval_options = ["month", "quarter", "bi_annual"]
	                  interval_options.push('annual') if same_price_across_the_board || split_deductible == true
	                  
	                  interval_options.each do |cur_interval|
	                    
                      rates[cur_interval] ||= []
                      rates[cur_interval].push({
                        'schedule' => schedule,
                        'sub_schedule' => sub_schedule,
                        'paid_in_full' => paid_in_full,
                        'liability_only' => liability_only,
                        'premium' => (qbe_rate.attributes["v"].value.delete(',').to_d * 100).to_i,
                        'deductibles' => deductibles,
                        'coverage_limits' => coverage_limits,
                        'individual_limit' => ((qbe_rate.attributes["indvllimit"]&.value&.delete(',') || 0).to_d * 100).to_i
                      })
                    
                      set_error = false          
                      process_status[:error] = false
	                    
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
	    
      # return false for failure, rates hash (which is truthy) for success
	    return process_status[:error] == true ? false : rates
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
	        return county_option['county'].downcase.titlecase
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
  
  
  # used for comparing county strings that may come from sources other than QBE
  def qbe_standardize_county_string(county_string)
    county_string.upcase.chomp(" COUNTY").chomp(" PARISH")
                 .gsub(/SAINT|STREET|ROAD|MOUNT/, { "SAINT" => "ST", "STREET" => "ST", "ROAD" => "RD", "MOUNT" => "MT" })
                 .gsub(/[^a-z]/i, '')
  end
end
