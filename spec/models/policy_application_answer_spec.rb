# == Schema Information
#
# Table name: policy_application_answers
#
#  id                          :bigint           not null, primary key
#  data                        :jsonb
#  section                     :integer          default("fields"), not null
#  policy_application_field_id :bigint
#  policy_application_id       :bigint
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#
require 'rails_helper'

RSpec.describe PolicyApplication, type: :model do
  it 'answer must be from options if options are defined' do

    agency = FactoryBot.create(:agency)
    account = FactoryBot.create(:account, agency: agency)
    carrier = Carrier.first
    carrier.agencies << [agency]
    policy_application = FactoryBot.create(:policy_application, carrier: carrier, agency: agency, account: account)
    policy_application_answer = FactoryBot.create(:policy_application_answer, policy_application: policy_application)
    policy_application_answer.data['options'] = ['test1', 'test2', 'test3']
    policy_application_answer.save
    policy_application_answer.data['answer'] = 'Not in options'
    expect(policy_application_answer).to_not be_valid
    policy_application_answer.errors[:data].should include('answer must be from options')
    
    policy_application_answer.data['answer'] = 'test1'
    expect(policy_application_answer).to be_valid
  end

  it 'answer must be from options if options are defined' do
    agency = FactoryBot.create(:agency)
    account = FactoryBot.create(:account, agency: agency)
    carrier = Carrier.first
    carrier.agencies << [agency]
    policy_application = FactoryBot.create(:policy_application, carrier: carrier, agency: agency, account: account)
    policy_application_answer = FactoryBot.create(:policy_application_answer, policy_application: policy_application)
    policy_application_answer.data['desired'] = 'test1'
    policy_application_answer.save
    policy_application_answer.data['answer'] = 'Not desired'
    expect(policy_application_answer).to_not be_valid
    policy_application_answer.errors[:data].should include('answer must match desired')
    
    policy_application_answer.data['answer'] = 'test1'
    expect(policy_application_answer).to be_valid
  end
end
