# =Pensio Policy Application Functions Concern
# file: +app/models/concerns/carrier_pensio_policy_application.rb+

module CarrierPensioPolicyApplication
  extend ActiveSupport::Concern


  included do

	  # Generate Quote
	  #

	  def pensio_quote

  	  quote_success = {
    	  error: false,
    	  success: false,
    	  message: nil,
    	  data: nil
  	  }

  	  status_check = self.complete? || self.quote_failed?

		  if status_check &&
			   self.carrier == Carrier.find_by_call_sign('P')

			  quote = policy_quotes.new(
					agency: self.agency,
					policy_group_quote: self.policy_application_group&.policy_group_quote
				)
			  if quote.save

				  guarantee_option = self.fields["guarantee_option"].to_i
					rent_amount = self.fields["monthly_rent"].to_i

					multiplier =
						if guarantee_option == 12
							0.09
						elsif guarantee_option == 6
							0.075
						else
							0.035
						end

				  minimum_premium =
				    if guarantee_option == 12
  				    108000
  				  elsif guarantee_option == 6
  				    90000
  				  else
  				    42000
  				  end

					unchecked_premium = ((( rent_amount * 100 ) * 12 ) * multiplier ).to_i
					checked_premium = unchecked_premium < minimum_premium ? minimum_premium : unchecked_premium

          quote_method = "mark_failure"
          premium = PolicyPremium.create policy_quote: quote
          unless premium.id
            puts "  Failed to create premium! #{premium.errors.to_h}"
          else
            result = premium.initialize_all(checked_premium)
            unless result.nil?
              puts "  Failed to initialize premium! #{result}"
            else
              quote_method = "mark_successful"
              quote_success[:success] = true
            end
          end

				else
					self.update status: "quote_failed"
          quote_success[:error] = true
          quote_success[:message] = I18n.t('policy_app_model.pensio.policy_quote_failed_to_return')
				end
			else
        quote_success[:error] = true
				quote_success[:message] = I18n.t('policy_app_model.pensio.application_unavailable')
			end

			return quote_success

		end

	end
end
