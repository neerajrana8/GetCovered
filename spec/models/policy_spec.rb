# frozen_string_literal: true

# == Schema Information
#
# Table name: policies
#
#  id                           :bigint           not null, primary key
#  number                       :string
#  effective_date               :date
#  expiration_date              :date
#  auto_renew                   :boolean          default(FALSE), not null
#  last_renewed_on              :date
#  renew_count                  :integer
#  billing_status               :integer
#  billing_dispute_count        :integer          default(0), not null
#  billing_behind_since         :date
#  status                       :integer
#  status_changed_on            :datetime
#  billing_dispute_status       :integer          default("UNDISPUTED"), not null
#  billing_enabled              :boolean          default(FALSE), not null
#  system_purchased             :boolean          default(FALSE), not null
#  serviceable                  :boolean          default(FALSE), not null
#  has_outstanding_refund       :boolean          default(FALSE), not null
#  system_data                  :jsonb
#  agency_id                    :bigint
#  account_id                   :bigint
#  carrier_id                   :bigint
#  policy_type_id               :bigint
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  policy_in_system             :boolean
#  auto_pay                     :boolean
#  last_payment_date            :date
#  next_payment_date            :date
#  policy_group_id              :bigint
#  declined                     :boolean
#  address                      :string
#  out_of_system_carrier_title  :string
#  policy_id                    :bigint
#  cancellation_reason          :integer
#  branding_profile_id          :integer
#  marked_for_cancellation      :boolean          default(FALSE), not null
#  marked_for_cancellation_info :string
#  marked_cancellation_time     :datetime
#  marked_cancellation_reason   :string
#  document_status              :integer          default("absent")
#  force_placed                 :boolean
#  cancellation_date            :date
#
ActiveJob::Base.queue_adapter = :test
include ActiveJob::TestHelper

RSpec.describe Policy, elasticsearch: true, type: :model do
  context 'master policy coverage' do
    before :all do
      # TODO: Need to refactor creation of all policy types into a method that runs
      # before all tests
      @residential_policy_type = PolicyType.find_by_title('Residential')
      @master_policy_type = PolicyType.find_by_title('Master Policy')
      @master_policy_coverage_type = PolicyType.find_by_title('Master Policy Coverage')
      @commercial_policy_type = PolicyType.find_by_title('Commercial')
      @rent_guarantee_policy_type = PolicyType.find_by_title('Rent Guarantee')
      
      @insurable_type_1 = InsurableType.find_by_title('Residential Community')
      @insurable_type_2 = InsurableType.find_by_title('Mixed Use Community')
      @insurable_type_3 = InsurableType.find_by_title('Commercial Community')
      @insurable_type_4 = InsurableType.find_by_title('Residential Unit')
      
      @agency = FactoryBot.create(:agency)
      @account = FactoryBot.create(:account, agency: @agency)
      @carrier = Carrier.find(1)
      ::CarrierAgency.create!(agency: @agency, carrier: @carrier, carrier_agency_policy_types_attributes: @carrier.carrier_policy_types.map do |cpt|
        {
          policy_type_id: cpt.policy_type_id,
          commission_strategy_attributes: { percentage: 9 }
        }
      end)
      
      @user = FactoryBot.create(:user)
      @master_policy = FactoryBot.build(:policy, :master, agency: @agency, carrier: @carrier, account: @account)
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
      expect(enqueued_jobs.size).to eq(0)
      # perform_enqueued_jobs do
      #   AutomaticMasterCoveragePolicyIssueJob.perform_later(master_policy.id)
      # end
      # expect(residential_unit.policies.count).to eq(1)
    end
  end
end
