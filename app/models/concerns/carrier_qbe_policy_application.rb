# =QBE Policy Application Functions Concern
# file: +app/models/concerns/carrier_qbe_policy.rb+

module CarrierQbePolicyApplication
  extend ActiveSupport::Concern

  included do

	  # QBE Estimate
	  #

	  def qbe_estimate(rates = nil, quote_id = nil)
			raise ArgumentError, I18n.t('policy_app_model.qbe.rates_cannot_be_nil') if policy_rates.count == 0  && rates.nil?
			raise ArgumentError, I18n.t('policy_app_model.qbe.rates_must_be_array') if policy_rates.count == 0  && !rates.is_a?(Array)

		  quote = quote_id.nil? ? policy_quotes.create!(agency: agency, account: account) :
		                          policy_quotes.find(quote_id)

		  if quote.persisted?
			  unless rates.nil?
					rates.each { |rate| policy_rates.create!(insurable_rate: rate) unless insurable_rates.include?(rate) }
				end

				policy_fee = self.primary_insurable().parent_community().insurable_rates
				                 .where(number_insured: self.fields[0]["value"],
				                        interval: self.billing_strategy.title.downcase.sub(/ly/, '').gsub('-', '_'),
				                        sub_schedule: "policy_fee").take

				policy_rates.create!(insurable_rate: policy_fee) unless policy_fee.nil?

				quote_rate_premiums = insurable_rates.map { |r| r.premium.to_f }
				quote.update est_premium: quote_rate_premiums.inject { |sum, rate| sum + rate },
				             status: "estimated"
			end
		end

		# QBE Add Policy Fee
		#

    def qbe_add_policy_fee
      if available_rates(:optional, :policy_fee).count > 0

        available_rates(:optional, :policy_fee).each do |policy_fee|
          rates << policy_fee
        end

      end
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
		  if status_check && self.carrier_id == QbeService.carrier_id
        # grab some values
        unit = primary_insurable()
        unit_profile = unit.carrier_profile(carrier.id)
        community = unit.parent_community()
        community_profile = community.carrier_profile(carrier.id)
        address = unit.primary_address()
        carrier_agency = CarrierAgency.where(agency: account.agency, carrier: self.carrier).take
        carrier_policy_type = CarrierPolicyType.where(carrier_id: QbeService.carrier_id, policy_type_id: PolicyType::RESIDENTIAL_ID).take

				if community_profile.data['ho4_enabled'] == true # If community profile is ho4_enabled

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
		            xml_doc = Nokogiri::XML(qbe_data[:data])
		            xml_min_prem = xml_doc.css('//Additional_Premium')

	 					    response_premium = xml_min_prem.attribute('total_premium').value.delete(".")
	 					    tax = xml_min_prem.attribute('tax').value.delete(".")
	 					    base_premium = response_premium.to_i - tax.to_i

                quote_method = "mark_failure"
                premium = PolicyPremium.create policy_quote: quote
                unless premium.id
                  puts "  Failed to create premium! #{premium.errors.to_h}"
                else
                  result = premium.initialize_all(base_premium.to_i, tax: tax.to_i, tax_recipient: quote.policy_application.carrier)
                  unless result.nil?
                    puts "  Failed to initialize premium! #{result}"
                  else
                    quote_method = "mark_successful"
                  end
                end
	 					    quote_method = premium.save ? "mark_successful" : "mark_failure"
	 					    quote.send(quote_method)
                
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
