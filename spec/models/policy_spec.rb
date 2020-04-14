# frozen_string_literal: true

RSpec.describe Policy, elasticsearch: true, type: :model do
  # it 'Policy with number 100 should be indexed' do
  #   FactoryBot.create(:policy, number: '100')
  #   Policy.__elasticsearch__.refresh_index!
  #   expect(Policy.search('100').records.length).to eq(1)
  # end

  # it 'Policy with wrong number 101 should not be indexed' do
  #   FactoryBot.create(:policy, number: '100')
  #   Policy.__elasticsearch__.refresh_index!
  #   expect(Policy.search('101').records.length).to eq(0)
  # end

  it 'should create insurance evidence' do
    @policy_type = FactoryBot.create(:policy_type)
    @agency = FactoryBot.create(:agency)
    @account = FactoryBot.create(:account, agency: @agency)
    @carrier = FactoryBot.create(:carrier)
    @carrier.policy_types << @policy_type
    @carrier.agencies << [@agency]
    @policy = FactoryBot.build(:policy, agency: @agency, carrier: @carrier, account: @account)
    @policy.policy_type = @policy_type
    @policy.policy_in_system = true
    @policy.save!
    @policy.pensio_issue_policy
  end



end
