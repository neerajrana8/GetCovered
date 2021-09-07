require 'rails_helper'

describe 'Insurables::UpdateCoveredStatus' do
  before :all do
    @user = create_user
    @agency = Agency.find(1)
    @account = FactoryBot.create(:account, agency: @agency)
    @carrier = Carrier.find(1)
    @policy_type = PolicyType.find(1)
  end


  let(:insurable) { FactoryBot.create(:insurable, :residential_unit) }
  let!(:policy) do
    FactoryBot.create(
      :policy,
      agency: @agency,
      carrier: @carrier,
      account: @account,
      policy_type: @policy_type,
      status: 'BOUND',
      effective_date: 10.days.ago,
      insurables: [insurable]
    )
  end
  it 'updates covered and expanded_covered fields' do
    Insurables::UpdateCoveredStatus.run!(insurable: insurable)
    insurable.reload
    expect(insurable.covered).to eq(true)
    expect(insurable.expanded_covered).to eq({ @policy_type.id.to_s => [policy.id] })
  end
end
