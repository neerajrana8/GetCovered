# =QBE Policy Application Functions Concern
# file: +app/models/concerns/carrier_qbe_policy.rb+

module CarrierQbePolicyApplication
  extend ActiveSupport::Concern

  included do

	  # QBE Estimate
	  #

	  def qbe_estimate(quote_id = nil)
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
      preferred = (unit.get_carrier_status(::QbeService.carrier_id) == :preferred)
      # get estimate
      results = ::InsurableRateConfiguration.get_coverage_options(
        carrier_policy_type, unit, self.coverage_selections, self.effective_date, address.state == 'MO' && self.policy_users.any?{|pu| pu.spouse } ? self.users.count - 2 : self.users.count - 1, self.billing_strategy,
        # execution options
        eventable: quote, # by passing a PolicyQuote we ensure results[:event], and results[:annotated_selections] get passed back out
        perform_estimate: true,
        add_selection_fields: true,
        # overrides
        additional_interest_count: preferred ? nil : self.extra_settings&.[]('additional_interest').blank? ? 0 : 1,
        agency: self.agency,
        account: self.account,
        nonpreferred_final_premium_params: community.get_qbe_traits(force_defaults: true, extra_settings: self.extra_settings, community: community, community_profile: community_profile, community_address: address)
      )
      # make sure we succeeded
      if !results[:valid]
        puts "Failed to perform QBE estimate: #{results[:errors]&.[](:internal)}"
        quote.mark_failure("Failed to perform QBE estimate: #{results[:errors]&.[](:internal)}")
        return nil
      elsif !self.update(coverage_selections: results[:annotated_selections]) # update our coverage selections with any annotations from the get_coverage_options call
        puts "Failed to update selections during QBE estimate: #{self.errors.to_h}"
        quote.mark_failure("Failed to update selections during QBE estimate: #{self.errors.to_h}")
        return nil
      end
      # save info
      unless quote.update(est_premium: results[:estimated_premium], status: 'estimated', carrier_payment_data: { 'policy_fee' => results[:policy_fee] })
        puts "Failed to update quote during QBE estimate: #{quote.errors.to_h}"
        quote.mark_failure("Failed to update quote during QBE estimate: #{quote.errors.to_h}")
        return nil
      end
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
        preferred = (unit.get_carrier_status(::QbeService.carrier_id) == :preferred)
        user_count = (address.state == 'MO' && self.policy_users.any?{|pu| pu.spouse } ? self.users.count - 1 : self.users.count)

				if community_profile.data['ho4_enabled'] == true && community_profile.data['rates_resolution'][user_count.to_s]

					update status: 'quote_in_progress'
	        event = events.new(
	          verb: 'post',
	          format: 'xml',
	          interface: 'SOAP',
	          process: 'get_qbe_min_prem',
	          endpoint: Rails.application.credentials.qbe[:uri][ENV["RAILS_ENV"].to_sym]
	        )

	        qbe_service = QbeService.new(action: 'getMinPrem')

          county = community_profile.data&.[]("county_resolution")&.[]("matches")&.find{|m| m["seq"] == community_profile.data["county_resolution"]["selected"] }&.[]("county") || address.county # we use the QBE formatted one in case .titlecase killed dashes etc.

	        qbe_request_options = {
            pref_facility: preferred ? 'MDU' : 'FIC',
	          prop_city: address.city,
	          prop_county: county,
	          prop_state: address.state,
	          prop_zipcode: address.combined_zip_code,
            effective_date: effective_date.strftime("%m/%d/%Y"),
	          premium: quote.est_premium.to_f / 100,
	          premium_pif: quote.est_premium.to_f / 100,
	          num_insured: user_count,
	          lia_amount: ((coverage_selections["liability"]&.[]('selection')&.[]('value') || 0).to_d / 100).to_f,
	          agent_code: carrier_agency.external_carrier_id
	        }.merge(community.get_qbe_traits(force_defaults: false, extra_settings: self.extra_settings, community: community, community_profile: community_profile, community_address: address))

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
                response_premium = (xml_min_prem.attribute('total_premium').value.delete(",").to_d * 100).to_i
                tax = (xml_min_prem.attribute('tax').value.delete(",").to_d * 100).to_i
                base_premium = response_premium - tax
                # create PolicyPremium
                succeeded = false
                premium = PolicyPremium.create(policy_quote: quote)
                policy_fee = quote.carrier_payment_data['policy_fee']
                premium.fees.create(title: "Policy Fee", type: 'ORIGINATION', amount_type: 'FLAT', amount: policy_fee, enabled: true, ownerable_type: "Carrier", ownerable_id: ::QbeService.carrier_id, hidden: true) unless policy_fee == 0
                unless premium.id
                  puts "  Failed to create premium! #{premium.errors.to_h}"
                else
                  result = premium.initialize_all(base_premium - policy_fee, tax: tax, tax_recipient: quote.policy_application.carrier)
                  unless result.nil?
                    puts "  Failed to initialize premium! #{result}"
                  else
                    succeeded = true
                  end
                end
	 					    quote_method = (succeeded && premium.save ? ["mark_successful"] : ["mark_failure", result || "Premium save failure: #{premium.errors.to_h}"])
	 					    quote.send(*quote_method)
                # end process
  	 						if quote.status == 'quoted'
                  result = quote.generate_invoices_for_term
                  unless result.nil?
                    puts result[:internal]
                    quote.mark_failure(I18n.t(result[:external]), result[:internal])
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
