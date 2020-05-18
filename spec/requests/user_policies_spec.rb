require 'rails_helper'
include ActionController::RespondWith

describe 'User Policy spec', type: :request do
  before :all do
    @user = create_user
    @policy_type = FactoryBot.create(:policy_type)
    @agency = FactoryBot.create(:agency)
    @account = FactoryBot.create(:account, agency: @agency)
    @carrier = FactoryBot.create(:carrier)
    @carrier.policy_types << @policy_type
    @carrier.agencies << @agency
    billing_strategy = BillingStrategy.create(title: "Monthly", slug: nil, enabled: true, new_business: {"payments"=>[8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], "payments_per_term"=>12, "remainder_added_to_deposit"=>true}, renewal: nil, locked: false, agency: @agency, carrier: @carrier, policy_type: @policy_type, carrier_code: nil)
    @bulk = PolicyGroup.create(effective_date: 1.day.from_now, expiration_date: 1.year.from_now, number: "PENSIOUSA3O8M4DCTJI69", policy_type: @policy_type, carrier: @carrier, agency: @agency, account: @account, policy_in_system: true)
    
    policy_application_group = PolicyApplicationGroup.create(policy_applications_count: 2, status: "quoted", account: @account, agency: @agency, effective_date: 1.day.from_now, expiration_date: 1.year.from_now, auto_renew: false, auto_pay: false, billing_strategy: billing_strategy, policy_group: @bulk, carrier: @carrier, policy_type: @policy_type)
    policy_group_quote = PolicyGroupQuote.create(reference: nil, external_reference: nil, status: "quoted", status_updated_on: 1.day.ago, premium: nil, tax: nil, est_fees: nil, total_premium: nil, policy_application_group: policy_application_group, policy_group: @bulk)
    @policy_group_premium = PolicyGroupPremium.create(base: 4518480, taxes: 0, total_fees: 0, total: 4518480, estimate: nil, calculation_base: 4518480, deposit_fees: 0, amortized_fees: 0, special_premium: 0, integer: 0, include_special_premium: false, boolean: false, carrier_base: 4518480, unearned_premium: -4518480, enabled: false, enabled_changed: nil, policy_group_quote: policy_group_quote, billing_strategy: billing_strategy, policy_group: @bulk)
    
    @policy = FactoryBot.create(:policy, agency: @agency, carrier: @carrier, account: @account, policy_group: @bulk)
    @second_policy = FactoryBot.create(:policy, agency: @agency, carrier: @carrier, account: @account, policy_group: @bulk)
    @third_policy = FactoryBot.create(:policy, agency: @agency, carrier: @carrier, account: @account, policy_group: @bulk)
    @fourth_policy = FactoryBot.create(:policy, agency: @agency, carrier: @carrier, account: @account, policy_group: @bulk)
    
    @policy.primary_user = @user
    @policy.save
    @user.skip_invitation = true
    @user.invite!
    @user.address = FactoryBot.create(:address)
    @user.save
    
    @quote = PolicyQuote.create(reference: "GC-B4JN3L4C6YYI", status: "quoted", status_updated_on: 1.day.ago, agency: @agency, account: @account, policy: @policy, policy_group_quote: policy_group_quote)
    @second_quote = PolicyQuote.create(reference: "GC-B4JN3L4C6YY2", status: "quoted", status_updated_on: 1.day.ago, agency: @agency, account: @account, policy: @second_policy, policy_group_quote: policy_group_quote)
    @third_quote = PolicyQuote.create(reference: "GC-B4JN3L4C6YY3", status: "quoted", status_updated_on: 1.day.ago, agency: @agency, account: @account, policy: @third_policy, policy_group_quote: policy_group_quote)
    @fourth_quote = PolicyQuote.create(reference: "GC-B4JN3L4C6YY4", status: "quoted", status_updated_on: 1.day.ago, agency: @agency, account: @account, policy: @fourth_policy, policy_group_quote: policy_group_quote)
    
    @policy_premium = PolicyPremium.create(base: 42000, taxes: 0, total_fees: 0, total: 42000, enabled: false, enabled_changed: nil, policy_quote: @quote, policy: @policy, billing_strategy: billing_strategy,  calculation_base: 42000, deposit_fees: 0, amortized_fees: 0, carrier_base: 42000, special_premium: 0, include_special_premium: false, unearned_premium: -42000)
    @second_policy_premium = PolicyPremium.create(base: 42084, taxes: 0, total_fees: 0, total: 42084, enabled: false, enabled_changed: nil, policy_quote: @second_quote, policy: @second_policy, billing_strategy: billing_strategy, calculation_base: 42084, deposit_fees: 0, amortized_fees: 0, carrier_base: 42084, special_premium: 0, include_special_premium: false, unearned_premium: -42084)
    @third_policy_premium = PolicyPremium.create(base: 42000, taxes: 0, total_fees: 0, total: 42000, enabled: false, enabled_changed: nil, policy_quote: @third_quote, policy: @third_policy, billing_strategy: billing_strategy, calculation_base: 42000, deposit_fees: 0, amortized_fees: 0, carrier_base: 42000, special_premium: 0, include_special_premium: false, unearned_premium: -42000)
    @fourth_policy_premium = PolicyPremium.create(base: 90270, taxes: 0, total_fees: 0, total: 90270, enabled: false, enabled_changed: nil, policy_quote: @fourth_quote, policy: @fourth_policy, billing_strategy: billing_strategy, calculation_base: 90270, deposit_fees: 0, amortized_fees: 0, carrier_base: 90270, special_premium: 0, include_special_premium: false, unearned_premium: -90270)
    
    @policy_group_premium.calculate_total
    policy_group_quote.generate_invoices_for_term(false, true)
  end
  
  
  it 'should not let cancel policy for bulk Policy Application without invitation_token' do
    get "/v2/user/policies/#{@policy.id}/bulk_decline"
    expect(response.body).to eq("{\"errors\":[\"Invalid token.\"]}")
    expect(response.status).to eq(406)
  end
  
  it 'should not let cancel policy for not primary user' do
    user = create_user
    user.skip_invitation = true
    user.invite!
    get "/v2/user/policies/#{@policy.id}/bulk_decline", params: {invitation_token: user.raw_invitation_token}
    expect(response.body).to eq("{\"errors\":[\"Unauthorized Access\"]}")
    expect(response.status).to eq(401)
  end
  
  it 'should render coi and summary' do
    get "/v2/user/policies/#{@policy.id}/render_eoi", params: {invitation_token: @user.raw_invitation_token}
    expect(response.status).to eq(200)
    result = JSON.parse response.body
    expect(result['evidence_of_insurance']).not_to be_empty
    expect(result['summary']).not_to be_empty
  end
  
  it 'should cancel policy for bulk Policy Application with refund if 30 days' do
    allow(Rails.application.credentials).to receive(:uri).and_return({ test: { client: 'localhost' } })
    UserCoverageMailer.with(policy: @policy, user: @user).acceptance_email.deliver
    last_mail = Nokogiri::HTML(ActionMailer::Base.deliveries.last.html_part.body.decoded)
    url = last_mail.css('a').first["href"]
    token = url[/confirm\/(.*?)\?/m, 1]
    policy_id = url[/policy_id=(.*?)$/, 1]
    expect(token).to eq(@user.raw_invitation_token)
    expect(policy_id.to_i).to eq(@policy.id)

    invoices = @policy_group_premium.policy_group_quote.invoices
    invoices.first.update(status: 'available')
    invoices.first.pay
    expect(@policy_group_premium.base).to eq(@policy_premium.base + @second_policy_premium.base + @third_policy_premium.base + @fourth_policy_premium.base)
    expect(invoices.first.total).to eq(18112)
    expect(invoices.second.total).to eq(18022)
    get "/v2/user/policies/#{@policy.id}/bulk_decline", params: {invitation_token: @user.raw_invitation_token}
    expect(response.status).to eq(200)
    expect(@policy.reload.declined).to eq(true)
    expect(@policy.policy_premiums&.last&.base).to eq(0)
    @policy_group_premium.reload
    
    # policygroup_premium should 174354
    expect(@policy_group_premium.base).to eq(@second_policy_premium.base + @third_policy_premium.base + @fourth_policy_premium.base)
    # Refund should be: premium for policy (42000) divided for 12 months = 
    expect(Refund.first&.amount).to eq(3500)
    # Invoice total should be: 18022 - premium for policy (42000) divided for 12 months = 14522
    invoices.quoted.reload.each do |invoice|
      expect(invoice.total).to eq(14522)
    end
  end

  it 'should send email if policy is accepted' do
    allow(Rails.application.credentials).to receive(:uri).and_return({ test: { client: 'localhost' } })
    user = create_user
    user.address = FactoryBot.create(:address)
    user.save
    @second_policy.primary_user = user
    @second_policy.save
    
    user.skip_invitation = true
    user.invite!
    get "/v2/user/policies/#{@second_policy.id}/bulk_accept", params: {invitation_token: user.raw_invitation_token}

    expect(response.status).to eq(200)
    expect(@second_policy.reload.declined).to eq(false)
  end
end

