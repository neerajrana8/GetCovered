require 'rails_helper'

describe 'PolicyRenewal::RenewedInvoicesGeneratorService' do
  before :all do
    @user = create_user
    @agency = Agency.find(1)
    @account = FactoryBot.create(:account, agency: @agency)
    @carrier = Carrier.find(1)
  end

  context 'update policy quotes, creates policy premiums and generate invoices' do
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

    xit 'generate new invoices for renewal process' do
      #TBD
      renewal_status = PolicyRenewal::RenewedInvoicesGeneratorService.call(policy.number)

    end

    xit 'raise exception during invoices generating for renewal process' do
      #TBD
      renewal_status = PolicyRenewal::RenewedInvoicesGeneratorService.call(policy.number)

    end
  end

end


