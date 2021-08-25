@leases = Lease.all.select{|l| !l.primary_user.nil? }
@qbe_id = 1
@msi_id = 5
@max_msi_coverage_selection_iterations = 5


@msi_test_card_data = {
  1257 => {
    token: "9495846215171111",
    card_info: {
      CreditCardInfo: {
        CardHolderName: "Payment Test",
        CardExpirationDate: "0125",
        CardType: "Visa",
        CreditCardLast4Digits: "1111",
        Addr: {
          Addr1: "2601 Lakeshore Dr",
          Addr2: nil,
          City: "Flower Mound",
          StateProvCd: "TX",
          PostalCode: "75028"
        }
      }
    }
  },
  47 => {
    token: "2738374128080004",
    card_info: {
      CreditCardInfo: {
        CardHolderName: "Payment Testing",
        CardExpirationDate: "0226",
        CardType: "Mastercard",
        CreditCardLast4Digits: "0004",
        Addr: {
          Addr1: "1414 Northeast Campus Parkway",
          Addr2: nil,
          City: "Seattle",
          StateProvCd: "WA",
          PostalCode: "98195"
        }
      }
    }
  }
}





@leases.each do |lease|
# 	if rand(0..100) > 33 # Create a 66% Coverage Rate

  if false && !lease.insurable.carrier_profile(@qbe_id).nil? && !ENV['SKIPQBE']
    carrier_id = @qbe_id
		#.insurable.carrier_profile(3)
		policy_type = PolicyType.find(1)
		billing_strategy = BillingStrategy.where(agency: lease.account.agency, policy_type: policy_type, carrier_id: carrier_id)
		                                  .order("RANDOM()")
		                                  .take
		
		application = PolicyApplication.new(
			effective_date: lease.start_date,
			expiration_date: lease.end_date,
			carrier_id: carrier_id,
			policy_type: policy_type,
			billing_strategy: billing_strategy,
			agency: lease.account.agency,
			account: lease.account
		)
		
		application.build_from_carrier_policy_type()
		application.fields[0]["value"] = lease.users.count
		application.insurables << lease.insurable
		
		if application.save()
			community = lease.insurable.parent_community
			
			primary_user = lease.primary_user()
			lease_users = lease.users.where.not(id: primary_user.id)
			
			application.users << primary_user
			lease_users.each { |u| application.users << u }
		  
		  # If application is set as complete
      if application.update status: 'complete'
					
				florida_check = application.primary_insurable().insurable.primary_address().state == "FL" ? true : false
	      deductibles = florida_check ? [50000, 100000] : [25000, 50000, 100000]
	      hurricane_deductibles = florida_check ? [50000, 100000, 250000, 500000] : nil 
	      
	      deductible = deductibles[rand(0..(deductibles.length - 1))]
	      
	      if florida_check == true
	        hurricane_deductible = 0
	        while hurricane_deductible < deductible
	          hurricane_deductible = hurricane_deductibles[rand(0..(hurricane_deductibles.length - 1))]
	        end
	      else
	        hurricane_deductible = nil
	      end

				query = florida_check ? "(deductibles ->> 'all_peril')::integer = #{ deductible } AND (deductibles ->> 'hurricane')::integer = #{ hurricane_deductible } AND number_insured = #{ lease.users.count }" : 
				                        "(deductibles ->> 'all_peril')::integer = #{ deductible } AND number_insured = #{ lease.users.count }"      

				coverage_c_rates = community.insurable_rates
				                            .activated
				                            .coverage_c
				                            .where(interval: application.billing_strategy.title.downcase.sub(/ly/, '').gsub('-', '_'))
				                            .where(query)
				
				liability_rates = community.insurable_rates
				                           .activated
				                           .liability
				                           .where(number_insured: lease.users.count, 
				                           				interval: application.billing_strategy.title.downcase.sub(/ly/, '').gsub('-', '_'))
	      
	      # Checking necessary rates have been found
	      unless coverage_c_rates.count == 0 || liability_rates.count == 0 || application.insurables.count == 0
		      		 
	        coverage_c_rate = coverage_c_rates[rand(0..(coverage_c_rates.count - 1))]
	        liability_rate = liability_rates[rand(0..(liability_rates.count - 1))]		      					

					application.insurable_rates << coverage_c_rate
					application.insurable_rates << liability_rate
					application.qbe_estimate()
					quote = application.policy_quotes.first
					
					# Quoting Policy Application
					if application.status != "quote_failed" || application.status != "quoted"
						application.qbe_quote(quote.id) 
						application.reload()
						quote.reload()
						
						if quote.status == "quoted"
  						
  						acceptance = quote.accept()
  						
              if acceptance[:success]
              
                quote.reload()
                
                premium = quote.policy_premium
                policy = quote.policy
                
                message = "POLICY #{ policy.number } has been #{ policy.status.humanize }\n"
                message += "Application ID: #{ application.id } | Application Status: #{ application.status } | Quote Status: #{ quote.status }\n" 
                message += "Premium Base: $#{ '%.2f' % (premium.total_premium.to_f / 100) } | Taxes: $#{ '%.2f' % (premium.total_tax.to_f / 100) } | Fees: $#{ '%.2f' % (premium.total_fee.to_f / 100) } | Total: $#{ '%.2f' % (premium.total.to_f / 100) }"
            
                puts message
              
              else
                
						  message = "QBE Quote Failed: Application #{ application.id } | Application Status: #{ application.status } | Quote #{quote.id} | Quote Status: #{ quote.status }"
              message += "\n  Accept message: #{acceptance[:message]}"
              puts message
              
              end
              
						else
						  puts "Application ID: #{ application.id } | Application Status: #{ application.status } | Quote Status: #{ quote.status }"
						end            
          end
          # End Quoting Policy Application
           
				end
	      # End Cgecjubg necessary rates have been found

		  end
		  # End If application is set as complete
			
		else
			pp application.errors	
		end
  end
  # end qbe
  
  carrier_id = (!lease.insurable.carrier_profile(@qbe_id).nil? && !ENV['SKIPQBE']) ? QbeService.carrier_id : (!lease.insurable.carrier_profile(@msi_id).nil? && !ENV['SKIPMSI']) ? MsiService.carrier_id : nil
  if carrier_id
    # grab useful variables & set up application
		policy_type = PolicyType.find(1)
		billing_strategy = BillingStrategy.where(agency: lease.account.agency, policy_type: policy_type, carrier_id: carrier_id)
		                                  .order("RANDOM()")
		                                  .take
		application = PolicyApplication.new(
			effective_date: lease.start_date,
			expiration_date: lease.end_date,
			carrier_id: carrier_id,
			policy_type: policy_type,
			billing_strategy: billing_strategy,
			agency: lease.account.agency,
			account: lease.account
		)
		# set application fields & add insurable
		application.build_from_carrier_policy_type()
		application.fields[0]["value"] = lease.users.count
    application.extra_settings = { "installment_day" => 1 }
		application.insurables << lease.insurable
    # add lease users
    primary_user = lease.primary_user()
    lease_users = lease.users.where.not(id: primary_user.id)
    application.users << primary_user
    lease_users.each { |u| application.users << u }
    # prepare to choose rates
    community = lease.insurable.parent_community
    cip = CarrierInsurableProfile.where(carrier_id: carrier_id, insurable_id: community.id).take
    effective_date = application.effective_date
    additional_insured_count = application.users.count - 1
    cpt = CarrierPolicyType.where(carrier_id: carrier_id, policy_type_id: 1).take
    # choose rates
    coverage_options = []
    coverage_selections = []
    result = { valid: false }
    iteration = 0
    max_iters = @max_msi_coverage_selection_iterations
    loop do
      iteration += 1
      result = ::InsurableRateConfiguration.get_coverage_options(
        cpt, community, coverage_selections, effective_date, additional_insured_count, billing_strategy,
        perform_estimate: false
      )
      if result[:valid]
        break
      elsif iteration > max_iters
        application.update(status: 'quote_failed')
        puts "Application ID: #{ application.id } | Application Status: #{ application.status } | Failed to find valid coverage options selection by #{max_iters}th iteration!!!"
        break
      elsif !result[:coverage_options].blank?
        coverage_selections = ::InsurableRateConfiguration.automatically_select_options(result[:coverage_options], coverage_selections)
      else
        application.update(status: 'quote_failed')
        puts "Application ID: #{ application.id } | Application Status: #{ application.status } | Failed to retrieve any coverage options!!!"
        break
      end
    end
    # continue creating policy
    if result[:valid]
      # mark application complete and save it
      application.coverage_selections = coverage_selections.select{|cs| cs['selection'] }
      application.status = 'complete'
      if !application.save
        pp application.errors
        puts "Application ID: 'NONE' | Application Status: #{ application.status } | Failed to save application!!!"
      else
        # create quote
        quote = application.estimate
        puts "  Got quote #{quote.class.name} : #{quote.respond_to?(:id) ? quote.id : 'no id'}"
        application.quote(quote.id)
        quote.reload
        if quote.id.nil? || quote.status != 'quoted'
          puts quote.errors.to_h.to_s unless quote.id
          puts "Application ID: #{ application.id } | Application Status: #{ application.status } | Quote ID: #{quote.id} | Quote Status: #{ quote.status }"
        else
          if carrier_id == ::QbeService.carrier_id
            acceptance = quote.accept
            if acceptance[:success]
              quote.reload
              premium = quote.policy_premium
              policy = quote.policy
              message = "POLICY #{ policy.number } has been #{ policy.status.humanize }\n"
              message += "Application ID: #{ application.id } | Application Status: #{ application.status } | Quote Status: #{ quote.status }\n" 
              message += "Premium Base: $#{ '%.2f' % (premium.total_premium.to_f / 100) } | Taxes: $#{ '%.2f' % (premium.total_tax.to_f / 100) } | Fees: $#{ '%.2f' % (premium.total_fee.to_f / 100) } | Total: $#{ '%.2f' % (premium.total.to_f / 100) }"
              puts message
            else
              message = "QBE Quote Failed: Application #{ application.id } | Application Status: #{ application.status } | Quote #{quote.id} | Quote Status: #{ quote.status }"
              message += "\n  Accept message: #{acceptance[:message]}"
              puts message
            end    
          elsif carrier_id == ::MsiService.carrier_id
            # grab test payment data
            test_payment_data = {
              'payment_method' => 'card',
              'payment_info' => @msi_test_card_data[quote.carrier_payment_data['product_id'].to_i][:card_info],
              'payment_token' => @msi_test_card_data[quote.carrier_payment_data['product_id'].to_i][:token],
            }
            # accept quote
            acceptance = quote.accept(bind_params: test_payment_data)
            if !quote.reload.policy.nil?
              # print a celebratory message
              premium = quote.policy_premium
              policy = quote.policy
              message = "POLICY #{ policy.number } has been #{ policy.status.humanize }\n"
              message += "Application ID: #{ application.id } | Application Status: #{ application.status } | Quote Status: #{ quote.status }\n" 
              message += "Premium Base: $#{ '%.2f' % (premium.total_premium.to_f / 100) } | Taxes: $#{ '%.2f' % (premium.total_tax.to_f / 100) } | Fees: $#{ '%.2f' % (premium.total_fee.to_f / 100) } | Total: $#{ '%.2f' % (premium.total.to_f / 100) }"
              puts message
            else
              puts "Application ID: #{ application.id } | Application Status: #{ application.status } | Quote Status: #{ quote.status }"
            end 
          end
        end
      end
    end
    
    
    
    
    
  # end msi
  end
# 	end	
end
