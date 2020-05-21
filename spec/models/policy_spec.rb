# frozen_string_literal: true
ActiveJob::Base.queue_adapter = :test
include ActiveJob::TestHelper

RSpec.describe Policy, elasticsearch: true, type: :model do
  context 'master policy coverage' do
    before :all do
      # TODO: Need to refactor creation of all policy types into a method that runs
      # before all tests
      @residential_policy_type = FactoryBot.create(:policy_type, title: "Residential", designation: "HO4", enabled: true)
      @master_policy_type = FactoryBot.create(:policy_type, title: "Master Policy", designation: "MASTER", enabled: true)
      @master_policy_coverage_type = FactoryBot.create(:policy_type, title: "Master Policy Coverage", designation: "MASTER-COVERAGE", enabled: true)
      @commercial_policy_type = FactoryBot.create(:policy_type, title: "Commercial", designation: "BOP", enabled: true)
      @rent_guarantee_policy_type = FactoryBot.create(:policy_type, title: "Rent Guarantee", designation: "RENT-GUARANTEE", enabled: true)
      
      @insurable_type_1 = FactoryBot.create(:insurable_type)
      @insurable_type_2 = FactoryBot.create(:insurable_type)
      @insurable_type_3 = FactoryBot.create(:insurable_type)
      @insurable_type_4 = FactoryBot.create(:insurable_type)
      
      @agency = FactoryBot.create(:agency)
      @account = FactoryBot.create(:account, agency: @agency)
      @carrier = FactoryBot.create(:carrier)
      @carrier.policy_types << [@residential_policy_type, @master_policy_type, @master_policy_coverage_type, @commercial_policy_type, @rent_guarantee_policy_type]
      @carrier.agencies << [@agency]
      @user = FactoryBot.create(:user)
      @master_policy = FactoryBot.build(:policy, agency: @agency, carrier: @carrier, account: @account)
      @master_policy.primary_user = @user
      @master_policy.policy_type = @master_policy_type
      @master_policy.status = 'BOUND'
      @master_policy.policy_in_system = true
      @master_policy.policy_coverages << PolicyCoverage.create(designation: 'liability_coverage')
      @master_policy.save
      
      @residential_community = FactoryBot.create(:insurable, account: @account, insurable_type: @insurable_type_1)
      @residential_unit = FactoryBot.create(:insurable, account: @account, insurable_type: @insurable_type_4)
    end
    
    it 'should create insurance evidence' do
      policy = FactoryBot.build(:policy, agency: @agency, carrier: @carrier, account: @account)
      policy.primary_user = @user
      policy.policy_type = @residential_policy_type
      policy.policy_in_system = true
      policy.save!
      policy.pensio_issue_policy
    end
    
    
    it 'policy coverage should not be valid without BOUND master policy' do
      policy_coverage = FactoryBot.build(:policy, agency: @agency, carrier: @carrier, account: @account)
      policy_coverage.primary_user = @user
      policy_coverage.policy_type = @master_policy_coverage_type
      policy_coverage.policy_in_system = true
      expect(policy_coverage).to_not be_valid
      expect(policy_coverage.errors.messages[:policy]).to eq ['must belong to BOUND Policy Coverage']
    end
    
    it 'policy coverage should not be valid without BOUND master policy' do
      policy_coverage = FactoryBot.build(:policy, agency: @agency, carrier: @carrier, account: @account)
      policy_coverage.primary_user = @user
      policy_coverage.policy_type = @master_policy_coverage_type
      policy_coverage.policy_in_system = true
      expect(policy_coverage).to_not be_valid
      expect(policy_coverage.errors.messages[:policy]).to eq ['must belong to BOUND Policy Coverage']
    end
    
    
    it 'should not validate expiration_date for policy coverage' do
      policy_coverage = FactoryBot.build(:policy, agency: @agency, carrier: @carrier, account: @account)
      policy_coverage.primary_user = @user
      policy_coverage.policy_type = @master_policy_coverage_type
      policy_coverage.policy_in_system = true
      policy_coverage.expiration_date = nil
      expect(policy_coverage.errors.messages[:expiration_date]).to be_empty
    end
    
    it 'policy coverage must inherit all master policy coverages' do
      
      policy_coverage = FactoryBot.build(:policy, agency: @agency, carrier: @carrier, account: @account)
      policy_coverage.primary_user = @user
      policy_coverage.policy_type = @master_policy_coverage_type
      policy_coverage.policy_in_system = true
      policy_coverage.expiration_date = nil
      policy_coverage.policy = @master_policy
      expect(policy_coverage).to be_valid
      policy_coverage.save
      expect(policy_coverage.policy_coverages.count).to eq(1)
      expect(policy_coverage.policy_coverages.first.designation).to eq('liability_coverage')
    end
    
    it 'should create automatic coverage policy issue' do
      clear_enqueued_jobs
      residential_community = FactoryBot.create(:insurable, account: @account, insurable_type: @insurable_type_1)
      residential_unit = FactoryBot.create(:insurable, account: @account, insurable_type: @insurable_type_4, insurable: residential_community)
      expect(residential_unit.policies.count).to eq(0)
      
      master_policy = FactoryBot.build(:policy, agency: @agency, carrier: @carrier, account: @account)
      master_policy.policy_type = @master_policy_type
      master_policy.status = 'BOUND'
      master_policy.policy_in_system = true
      master_policy.policy_coverages << PolicyCoverage.create(designation: 'liability_coverage')
      master_policy.insurables << residential_community
      master_policy.save
      expect(enqueued_jobs.size).to eq(1)
      byebug
      # perform_enqueued_jobs do
      #   AutomaticMasterCoveragePolicyIssueJob.perform_later(master_policy.id)
      # end
      # expect(residential_unit.policies.count).to eq(1)
    end
    
  end
  
end
