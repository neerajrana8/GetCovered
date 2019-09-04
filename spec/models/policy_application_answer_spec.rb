require 'rails_helper'

RSpec.describe PolicyApplication, type: :model do
  it 'answer must be from options if options are defined' do
    policy_application_answer = FactoryBot.create(:policy_application_answer)
    policy_application_answer.data['options'] = ['test1', 'test2', 'test3']
    policy_application_answer.save
    policy_application_answer.data['answer'] = 'Not in options'
    expect(policy_application_answer).to_not be_valid
    policy_application_answer.errors[:data].should include('answer must be from options')
    
    policy_application_answer.data['answer'] = 'test1'
    expect(policy_application_answer).to be_valid
  end

  it 'answer must be from options if options are defined' do
    policy_application_answer = FactoryBot.create(:policy_application_answer)
    policy_application_answer.data['desired'] = 'test1'
    policy_application_answer.save
    policy_application_answer.data['answer'] = 'Not desired'
    expect(policy_application_answer).to_not be_valid
    policy_application_answer.errors[:data].should include('answer must match desired')
    
    policy_application_answer.data['answer'] = 'test1'
    expect(policy_application_answer).to be_valid
  end

  
end