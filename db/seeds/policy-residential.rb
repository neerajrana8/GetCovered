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
    # save the dang application
    application.save!
    # prepare to choose rates
    community = lease.insurable.parent_community
    cip = CarrierInsurableProfile.where(carrier_id: carrier_id, insurable_id: community.id).take
    effective_date = application.effective_date
    additional_insured_count = application.users.count - 1
    cpt = CarrierPolicyType.where(carrier_id: carrier_id, policy_type_id: 1).take
    # choose rates
    coverage_options = {}
    coverage_selections = {}
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
        # just in case you want to see selections and errors from failed iterations:
        #puts "Iteration #{iteration}; selections #{coverage_selections}"
        #puts "Errors: #{result[:errors]&.[](:internal)}"
        coverage_selections = ::InsurableRateConfiguration.automatically_select_options(result[:coverage_options], coverage_selections)
      else
        application.update(status: 'quote_failed')
        puts "Application ID: #{ application.id } | Application Status: #{ application.status } | Failed to retrieve any coverage options!!!"
        puts "GCO results: #{result}"
        break
      end
    end
    # continue creating policy
    if result[:valid]
      # mark application complete and save it
      application.coverage_selections = coverage_selections.select{|k,cs| cs['selection'] }
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
