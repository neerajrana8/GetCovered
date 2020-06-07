require 'rails_helper'
include ActionController::RespondWith

describe 'Commissions API spec', type: :request do
  ActiveJob::Base.queue_adapter = :test
  before :all do
    @carrier = Carrier.first
    @policy_type = @carrier.policy_types.take
    @staff = FactoryBot.create(:staff, role: 'super_admin')
    @getcovered_agency = FactoryBot.create(:agency)
    @cambridge_agency = FactoryBot.create(:agency, title: "Cambridge")
    @account = FactoryBot.create(:account, agency: @cambridge_agency)
    @carrier.agencies << [@getcovered_agency, @cambridge_agency]
    @getcovered_commission_strategy = FactoryBot.build(:commission_strategy, carrier: @carrier, policy_type: @policy_type, type: 'PERCENT', amount: 30, commissionable: @getcovered_agency)
    @getcovered_commission_strategy.save!
    @cambridge_commission_strategy = FactoryBot.build(:commission_strategy, carrier: @carrier, policy_type: @policy_type, type: 'FLAT', amount: 500)
    @cambridge_commission_strategy.commissionable = @cambridge_agency
    @cambridge_commission_strategy.commission_strategy = @getcovered_commission_strategy
    @cambridge_commission_strategy.save!
    @policy = FactoryBot.build(:policy, agency: @cambridge_agency, carrier: @carrier, account: @account)
    @policy.policy_type = @policy_type
    @policy.save!
    @policy_quote = FactoryBot.create(:policy_quote, agency: @getcovered_agency, policy: @policy)
    @billing_strategy = FactoryBot.create(:monthly_billing_strategy, agency: @getcovered_agency, carrier: @carrier, policy_type: @policy_type)
    @policy_premium = FactoryBot.build(:policy_premium, policy_quote: @policy_quote, billing_strategy: @billing_strategy)
    @policy_premium.base = 10000
    @policy_premium.total = @policy_premium.base + @policy_premium.taxes + @policy_premium.total_fees
    @policy_premium.calculation_base = @policy_premium.base + @policy_premium.taxes + @policy_premium.amortized_fees
    @policy_premium.policy = @policy
    @policy_premium.save!
    CommissionService.new(@cambridge_commission_strategy, @policy_premium).process
  end
  
  before :each do
    login_staff(@staff)
    @headers = get_auth_headers_from_login_response_headers(response)
  end
  
  context 'for SuperAdmin roles' do
    
    it 'should show Commission' do
      commission = Commission.first
      get "/v2/staff_super_admin/commissions/#{commission.id}", headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["id"]).to eq(commission.id)
    end
    
    it 'should show a list of Commissions' do
      get "/v2/staff_super_admin/commissions", headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result.count).to eq(2)
    end
    
    
    it 'should update Commission' do
      commission = Commission.first
      distributes = 1.day.from_now
      put "/v2/staff_super_admin/commissions/#{commission.id}", params: { commission: {distributes: distributes } }, headers: @headers
      result = JSON.parse response.body
      expect(response.status).to eq(200)
      expect(result["distributes"]).to eq(distributes.strftime("%F"))
    end
    
    it 'should approve Commission' do
      commission = Commission.first
      expect {
        put "/v2/staff_super_admin/commissions/#{commission.id}/approve", headers: @headers
      }.to have_enqueued_job(StripeCommissionPayoutJob)
    end
    
    
  end
  
end 
