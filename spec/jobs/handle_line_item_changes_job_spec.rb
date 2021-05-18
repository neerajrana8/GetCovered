# frozen_string_literal: true

require 'rails_helper'

describe 'HandleLineItemChangesJob' do
  before :all do
    # create a new agency and set it up to support everything GetCovered supports, with all commissions set to 5%
    agency = FactoryBot.create(:agency)
    CarrierAgency.where(agency_id: 1).each do |carrier_agency|
      ::CarrierAgency.create!(agency: agency, carrier: carrier_agency.carrier, carrier_agency_policy_types_attributes: carrier.carrier_policy_types.map do |cpt|
        {
          policy_type_id: cpt.policy_type_id,
          commission_strategy_attributes: { percentage: 5 }
        }
      end)
    end
    # create an account and unit
    account = FactoryBot.create(:account, agency: agency)
    community = FactoryBot.create(:insurable, :residential_community, account: account)
    unit = FactoryBot.create(:insurable, :residential_unit, account: account, insurable: community)
  end
  
  
  
  it "correctly generates commissions" do
  end


end
