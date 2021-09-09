# frozen_string_literal: true

require 'rails_helper'


describe 'HandleLineItemChangesJob' do
  before :all do
    # create a new agency and set it up to support everything GetCovered supports, with all commissions set to 5%
    agency = FactoryBot.create(:agency)
    qbe_id_number = (CarrierAgency.all.pluck(:external_carrier_id).select{|eci| eci && eci.start_with?("TESTBOI") }
                                                          .map{|eci| eci[7..-1].to_i }
                                                          .max || 0)
    CarrierAgency.where(agency_id: 1).each do |carrier_agency|
      ::CarrierAgency.create!(agency: agency, carrier: carrier_agency.carrier, external_carrier_id: carrier_agency.carrier.id == 1 ? "TESTBOI#{qbe_id_number += 1}" : nil, carrier_agency_policy_types_attributes: carrier_agency.carrier.carrier_policy_types.map do |cpt|
        {
          policy_type_id: cpt.policy_type_id,
          commission_strategy_attributes: { percentage: 5 }
        }
      end)
    end
    # create an account and unit
    account = FactoryBot.create(:account, agency: agency)
    ::Address.create!(
      addressable: account,
      street_number: "1725",
      street_name: "Harvey Mitchell Pkwy S",
      city: "College Station",
      county: "BRAZOS",
      state: "TX",
      zip_code: "77840",
      plus_four: "6312",
      primary: true
    )
    # make variables accessible to folk
    @agency = agency
    @account = account
  end
  
  
=begin
  it "correctly generates commissions" do
    # create the policy
    policy = Helpers::CompletePolicyGenerator.create_complete_qbe_policy(account: @account, agency: @agency)
    expect(policy.id.nil?).to eq(false)
    # pay the invoices
    policy.invoices.order('due_date asc').each do |invoice|
      unless invoice.status == 'complete'
        invoice.update(available_date: Time.current.to_date - 1.day)
        result = invoice.pay(stripe_source: :default)
        invoice.reload
        expect(result[:success]).to eq(true), "payment attempt failed with output: #{result}"
      end
    end
    # run the job
    HandleLineItemChangesJob.perform_now
    # check the commissions numbers
    
  end
=end

end
