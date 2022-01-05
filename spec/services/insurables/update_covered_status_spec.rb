require 'rails_helper'

describe 'Insurables::UpdateCoveredStatus' do
  before :all do
    @user = create_user
    @agency = Agency.find(1)
    @account = FactoryBot.create(:account, agency: @agency)
    @carrier = Carrier.find(1)
  end


  context 'update single insurable' do
    let(:insurable) { FactoryBot.create(:insurable, :residential_unit) }
    let(:policy_type) { PolicyType.find(PolicyType::RESIDENTIAL_ID) }
    let!(:policy) do
      FactoryBot.create(
        :policy,
        agency: @agency,
        carrier: @carrier,
        account: @account,
        policy_type: policy_type,
        status: 'BOUND',
        effective_date: 10.days.ago,
        insurables: [insurable]
      )
    end
    it 'updates covered and expanded_covered fields' do
      Insurables::UpdateCoveredStatus.run!(insurable: insurable)
      insurable.reload
      expect(insurable.covered).to eq(true)
      expect(insurable.expanded_covered).to eq(policy_type.id.to_s => [policy.id])
    end
  end
  
  context 'update multiple insurables' do
    let(:policy_type_residential) { PolicyType.find(PolicyType::RESIDENTIAL_ID) }
    let(:policy_type_master) { PolicyType.find(PolicyType::MASTER_ID) }
    let!(:residential_unit) { FactoryBot.create(:insurable, :residential_unit) }
    let!(:residential_community) { FactoryBot.create(:insurable, :residential_community) }

    let!(:policy) do
      FactoryBot.create(
        :policy,
        agency: @agency,
        carrier: @carrier,
        account: @account,
        policy_type: policy_type_residential,
        status: 'BOUND',
        effective_date: 10.days.ago,
        insurables: [residential_unit]
      )
    end
    let!(:master_policy) do
      FactoryBot.create(
        :policy,
        agency: @agency,
        carrier: @carrier,
        account: @account,
        policy_type: policy_type_master,
        status: 'BOUND',
        effective_date: 10.days.ago,
        insurables: [residential_community]
      )
    end

    it 'updates covered and expanded_covered fields for all ' do
      Insurables::UpdateCoveredStatus.run!
      residential_unit.reload
      residential_community.reload
      expect(residential_unit.covered).to eq(true)
      expect(residential_community.covered).to eq(true)
      expect(residential_unit.expanded_covered).to eq(policy_type_residential.id.to_s => [policy.id])
      expect(residential_community.expanded_covered).to eq(policy_type_master.id.to_s => [master_policy.id])
    end
  end
end
