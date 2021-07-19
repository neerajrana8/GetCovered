module Helpers
  class CompletePolicyGenerator
  
    def self.setup_unit_for_qbe(unit)
      community = unit.parent_community
      if community.carrier_profile(1).nil?
        profile = community.create_carrier_profile(1)
        profile.traits['construction_year'] = rand(1979..2005)
        profile.traits['professionally_managed'] = true
        profile.traits['professionally_managed_year'] = profile.traits['construction_year'] + 1
        profile.save
        community.get_qbe_zip_code
        community.get_qbe_property_info
        community.units.each do |current_unit|
          current_unit.create_carrier_profile(1) unless current_unit.carrier_profile(1)
        end
        community.reset_qbe_rates(true, true)
        # debug screaming
        failed_events = ::Event.where(eventable: community, status: "error").to_a
        unless failed_events.blank?
          puts "**********************************************"
          puts "* QBE community setup event errors occurred (spec/support/helpers/complete_policy_generator.rb:4)! *"
          failed_events.each{|evt| puts "-------------"; puts "\n"; puts evt.request; puts "\n"; puts evt.response; puts "\n"; puts "---------" }
          puts "**********************************************"
        end
      end
    end
    
    def self.create_complete_qbe_policy(
      unit: nil,
      account: unit&.account || unit&.insurable&.account || unit&.insurable&.insurable&.account,
      agency: account&.agency || Agency.find(1),
      user: FactoryBot.create(:user)
    )
      # fix params
      account ||= FactoryBot.create(:account, agency: agency)
      if unit.nil?
        community = FactoryBot.create(:insurable, :residential_community, account: account)
        ::Address.create!(
          street_number: "105",
          street_name: "N Elm St",
          city: "Mahomet",
          county: "Champaign",
          state: "IL",
          zip_code: "61853",
          plus_four: "9364",
          primary: true,
          addressable_type: "Insurable",
          addressable_id: community.id
        )
        unit = FactoryBot.create(:insurable, :residential_unit, account: account, insurable: community)
      end
      # preprocessing
      setup_unit_for_qbe(unit)
      user.attach_payment_source("tok_visa", true)
      # build stuff
      carrier = Carrier.find(1)
      policy_type = PolicyType.find(1)
      billing_strategy = BillingStrategy.where(carrier: carrier, agency: agency, policy_type: policy_type).last
      application = PolicyApplication.new(
        effective_date: Time.current.to_date + 2.days,
        expiration_date: (Time.current.to_date + 2.days) + 1.year,
        carrier: carrier,
        policy_type: policy_type,
        billing_strategy: billing_strategy,
        agency: agency,
        account: account
      )
      application.build_from_carrier_policy_type
      application.fields[0]["value"] = 1
      application.insurables << unit
      throw "QBE application failed to save: #{application.errors.to_h}" unless application.save
      application.users << user
      throw "QBE application failed to complete: #{application.errors.to_h}" unless application.update(status: 'complete')
      # hideous hell-born monstrosity code
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
      query = florida_check ? "(deductibles ->> 'all_peril')::integer = #{ deductible } AND (deductibles ->> 'hurricane')::integer = #{ hurricane_deductible } AND number_insured = 1" : 
                              "(deductibles ->> 'all_peril')::integer = #{ deductible } AND number_insured = 1"
      coverage_c_rates = community.insurable_rates
                                  .activated
                                  .coverage_c
                                  .where(interval: application.billing_strategy.title.downcase.sub(/ly/, '').gsub('-', '_'))
                                  .where(query)
      liability_rates = community.insurable_rates
                                 .activated
                                 .liability
                                 .where(number_insured: 1, 
                                        interval: application.billing_strategy.title.downcase.sub(/ly/, '').gsub('-', '_'))
      throw "QBE application failed; no applicable coverage_c_rates!" if coverage_c_rates.count == 0
      throw "QBE application failed; no applicable liability_rates!" if liability_rates.count == 0
      throw "QBE application failed; even though insurable was attached, application has no insurables!" if application.insurables.count == 0
      
      coverage_c_rate = coverage_c_rates[rand(0..(coverage_c_rates.count - 1))]
      liability_rate = liability_rates[rand(0..(liability_rates.count - 1))]		      					
      application.insurable_rates << coverage_c_rate
      application.insurable_rates << liability_rate
      # get the quote
      application.qbe_estimate
      quote = application.policy_quotes.first
      throw "QBE quote failed: #{application.error_message}" if application.status == 'quote_failed'
      application.qbe_quote(quote.id)
      application.reload
      quote.reload
      throw "QBE quote failed to be quoted: #{application.error_message || "no application error_message"}" if quote.status != 'quoted'
      # accept the quote
      acceptance = quote.accept
      throw "QBE quote failed to bind (APPID #{application.id}, APPSTATUS #{application.status}, QUOTEID #{quote.id}, QUOTESTATUS #{quote.status}): #{acceptance[:message]}" unless acceptance[:success]
      quote.reload
      return quote.policy      
    end
    
  
  
  end
end
