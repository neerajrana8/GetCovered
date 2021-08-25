# =QBE Policy Application Functions Concern
# file: +app/models/concerns/carrier_qbe_policy.rb+

module CarrierQbePolicyApplication
  extend ActiveSupport::Concern

  included do

	  # QBE Estimate
	  #

	  def qbe_estimate(rates = nil, quote_id = nil)
      # get the quote
		  quote = quote_id.nil? ? policy_quotes.create!(agency: agency, account: account) : quote_id.class == ::PolicyQuote ? quote_id : policy_quotes.find(quote_id)
      quote_id = quote.id if quote_id.class == ::PolicyQuote
      # grab some values
      unit = self.primary_insurable
      unit_profile = unit.carrier_profile(self.carrier_id)
      community = unit.parent_community
      community_profile = community.carrier_profile(self.carrier_id)
      address = unit.primary_address
      carrier_agency = CarrierAgency.where(agency_id: self.agency_id, carrier_id: self.carrier_id).take
      carrier_policy_type = CarrierPolicyType.where(carrier_id: self.carrier_id, policy_type_id: PolicyType::RESIDENTIAL_ID).take
      preferred = (unit.get_carrier_status == :preferred)
      # get estimate
      results = ::InsurableRateConfiguration.get_coverage_options(
        carrier_policy_type, unit, self.coverage_selections, self.effective_date, self.users.count - 1, self.billing_strategy, # MOOSE WARNING: spouse nonsense
        # execution options
        eventable: quote, # by passing a PolicyQuote we ensure results[:event], and results[:annotated_selections] get passed back out
        perform_estimate: true,
        add_selection_fields: true,
        # overrides
        additional_interest_count: preferred ? nil : self.extra_settings['additional_interest'].blank? ? 0 : 1,
        agency: self.agency,
        account: self.account#,
        # nonpreferred stuff
        #nonpreferred_final_premium_params: {
        #  address_line_two: unit.title.nil? ? nil : "Unit #{unit.title}",
        #  number_of_units: self.extra_settings&.[]('number_of_units'),
        #  years_professionally_managed: self.extra_settings&.[]('years_professionally_managed'),
        #  year_built: self.extra_settings&.[]('year_built'),
        #  gated: self.extra_settings&.[]('gated')
        #}.compact
      )
      # make sure we succeeded
      if !results[:valid] # MOOSE WARNING: add error messages
        return nil
      elsif !self.update(coverage_selections: results[:annotated_selections]) # update our coverage selections with any annotations from the get_coverage_options call
        return nil
      end
      # save info
      quote.update(est_premium: results[:estimated_premium], status: 'estimated', carrier_payment_data: { 'policy_fee' => results[:policy_fee] })
      return quote
		end

	  # QBE Quote
	  #
	  # Takes Policy Application data and
	  # sends to QBE to create a quote

	  def qbe_quote(quote_id = nil)
			raise ArgumentError, I18n.t('policy_app_model.qbe.quote_id_cannot_be_nil') if quote_id.nil?

		  quote_success = false
		  status_check = self.complete? || self.quote_failed?
		  quote = policy_quotes.find(quote_id)

		  # If application complete or quote_failed
		  # and carrier is QBE will figure out the
		  # "I" later - Dylan August 10, 2019
		  if status_check && self.carrier_id == QbeService.carrier_id && quote.status == 'estimated'
        # grab some values
        unit = self.primary_insurable
        unit_profile = unit.carrier_profile(self.carrier_id)
        community = unit.parent_community
        community_profile = community.carrier_profile(self.carrier_id)
        address = unit.primary_address
        carrier_agency = CarrierAgency.where(agency_id: self.agency_id, carrier_id: self.carrier_id).take
        carrier_policy_type = CarrierPolicyType.where(carrier_id: self.carrier_id, policy_type_id: PolicyType::RESIDENTIAL_ID).take
        preferred = (unit.get_carrier_status == :preferred)

				if community_profile.data['ho4_enabled'] == true && community_profile.data['rates_resolution'][self.users.count] # MOOSE WARNING: spouse logic...

					update status: 'quote_in_progress'
	        event = events.new(
	          verb: 'post',
	          format: 'xml',
	          interface: 'SOAP',
	          process: 'get_qbe_min_prem',
	          endpoint: Rails.application.credentials.qbe[:uri][ENV["RAILS_ENV"].to_sym]
	        )

	        qbe_service = QbeService.new(action: 'getMinPrem')

	        qbe_request_options = {
	          prop_city: address.city,
	          prop_county: address.county,
	          prop_state: address.state,
	          prop_zipcode: address.combined_zip_code,
	          city_limit: community_profile.traits['city_limit'] == true ? 1 : 0,
	          units_on_site: community.units.confirmed.count,
	          age_of_facility: community_profile.traits['construction_year'],
	          gated_community: community_profile.traits['gated'] == true ? 1 : 0,
	          prof_managed: community_profile.traits['professionally_managed'] == true ? 1 : 0,
	          prof_managed_year: community_profile.traits['professionally_managed_year'] == true ? "" : community_profile.traits['professionally_managed_year'],
	          effective_date: effective_date.strftime("%m/%d/%Y"),
	          premium: quote.est_premium.to_f / 100,
	          premium_pif: quote.est_premium.to_f / 100,
	          num_insured: users.count,
	          lia_amount: ((coverage_selections["liability"] || 0).to_d / 100).to_f,
	          agent_code: carrier_agency.external_carrier_id
	        }

	        qbe_service.build_request(qbe_request_options)

	        event.request = qbe_service.compiled_rxml

	        if event.save # If event saves after creation
	          event.started = Time.now
	          qbe_data = qbe_service.call()
	          event.completed = Time.now

		        event.response = qbe_data[:data]
		        event.status = qbe_data[:error] ? 'error' : 'success'
		        if event.save # If event saves after QBE call
			        unless qbe_data[:error] # QBE Response Success
                # parse xml
		            xml_doc = Nokogiri::XML(qbe_data[:data])
		            xml_min_prem = xml_doc.css('//Additional_Premium')
	 					    response_premium = xml_min_prem.attribute('total_premium').value.delete(".")
	 					    tax = xml_min_prem.attribute('tax').value.delete(".")
	 					    base_premium = response_premium.to_i - tax.to_i
                # create PolicyPremium
                succeeded = false
                premium = PolicyPremium.create(policy_quote: quote)
                policy_fee = quote.carrier_payment_data['policy_fee']
                premium.fees.create(title: "Policy Fee", type: 'ORIGINATION', amount_type: 'FLAT', amount: policy_fee, enabled: true, ownerable: ::MsiService.carrier, hidden: true) unless policy_fee == 0
                unless premium.id
                  puts "  Failed to create premium! #{premium.errors.to_h}"
                else
                  result = premium.initialize_all(base_premium.to_i - policy_fee, tax: tax.to_i, tax_recipient: quote.policy_application.carrier)
                  unless result.nil?
                    puts "  Failed to initialize premium! #{result}"
                  else
                    succeeded = true
                  end
                end
	 					    quote_method = succeeded && premium.save ? "mark_successful" : "mark_failure"
	 					    quote.send(quote_method)
                # end process
  	 						if quote.status == 'quoted'
                  result = quote.generate_invoices_for_term
                  unless result.nil?
                    puts result[:internal] # MOOSE WARNING: [:external] contains an I81n key for a user-displayable message, if desired
                    quote.mark_failure(result[:internal])
                    return false
                  end
		 							return true
		 						else
		 							puts "\nQuote Save Error\n"
		 							pp quote.errors
		 							return false
		 						end

		 					else # QBE Response Success Failure

		 						puts "\QBE Request Unsuccessful, Event ID: #{ event.id }"
		 						quote.mark_failure()
		 						return false

 							end # / QBE Response Success
 						else

		 					puts "\Post QBE Request Event Save Error"
 							quote.mark_failure()
 							return false

			      end # / If event saves after QBE call
			    else

			    	quote.mark_failure()
			    	return false

					end # / If event saves after creation
				end # / If community profile is ho4_enabled

		  end # If application complete and carrier is QBE
    end

  end
end
