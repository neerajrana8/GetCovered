# =Crum & Forester Policy Application Functions Concern
# file: +app/models/concerns/carrier_crum_policy_application.rb+

module CarrierCrumPolicyApplication
  extend ActiveSupport::Concern

  included do

	  # Generate Quote
	  #

	  def crum_quote(quote_id = nil)

  	  quote_success = {
    	  error: false,
    	  success: false,
    	  message: nil,
    	  data: nil
  	  }

  	  status_check = self.complete? || self.quote_failed?

		  if status_check &&
			   self.carrier == Carrier.find_by_call_sign('CF')

        crum_service = CrumService.new()
        request_template = crum_service.build_request_template("add_new_quote", self)

        event = self.events.new(request: request_template.to_json,
                                started: Time.now, status: "in_progress",
                                verb: 'post', process: 'new_crum_quote', interface: 'REST',
                                endpoint: Rails.application.credentials.crum[:uri][:add_quote])

        if event.save

          self.update status: "quote_in_progress"
          request = crum_service.add_new_quote(request_template)

          event.update completed: Time.now, response: request[:data], status: request[:error] ? "error" : "success"

          unless request[:error] || request[:data].has_key?("responseMessages")

            data = request[:data]

            if data["quoteDetails"]["policyService"]["isEligible"] == "Yes"

              quote_success[:success] = true
              policy_header = data["quoteDetails"]["policyService"]["policyHeader"]
              policy_details = data["quoteDetails"]["policyService"]["data"]["policy"]
              self.update external_reference: policy_header["policyNumber"], status: "quoted"

              quote = policy_quotes.new(
                external_reference: policy_header["policyNumber"],
                external_id: policy_details["quoteID"],
                agency: self.agency
              )

              if quote.save

                policy_details["liablityCoverages"].keys.each do |key|
                  quote.policy_application.policy_coverages.create!(
                    designation: key,
                    limit: policy_details["liablityCoverages"][key].to_i * 100
                  )
                end
                
                #########
                quote_method = "mark_failure"
                premium = PolicyPremium.create policy_quote: quote
                unless premium.id
                  puts "  Failed to create premium! #{premium.errors.to_h}"
                else
                  result = premium.initialize_all(
                    (policy_details["termPremium"].include?(".") ?  policy_details["termPremium"].delete(".").to_i : policy_details["termPremium"].to_i * 100) + policy_details["triaPremium"].to_i * 100
                    # the triaPremium bit is the old special_premium
                  )
                  unless result.nil?
                    puts "  Failed to initialize premium! #{result}"
                  else
                    quote_method = "mark_successful"
                  end
                end
	 					    quote_method = premium.save ? "mark_successful" : "mark_failure"
	 					    quote.send(quote_method)

	 					    PolicyQuoteGetDocumentsJob.set(wait: 1.minutes).perform_later(quote: quote)

                quote_success[:success] = true

              else

                pp quote.errors
                quote_success[:error] = true
                quote_success[:success] = false

              end
            else

              messages = []
              self.update status: "rejected"

              data["quoteDetails"]["policyService"]["responseMessages"].each do |message|
                messages << message["responseMessage"].to_s
              end

              quote_success[:message] = messages.join(", ")

              pp quote_success

            end
          else

            self.update status: "quote_failed"
            quote_success[:error] = true
            quote_success[:message] = I18n.t('policy_app_model.pensio.policy_quote_failed_to_return')
          end
        else
          quote_success[:error] = true
          quote_success[:message] = I18n.t('policy_app_model.crum.event_failed')
        end
      end

      return quote_success

    end

  end
end
