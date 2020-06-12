require 'rails_helper'
include ActionController::RespondWith

describe 'Histories API spec', type: :request do
  before :all do
    @agency = FactoryBot.create(:agency)
    @staff = create_agent_for @agency
  end
  
  before :each do
    login_staff(@staff)
    @headers = get_auth_headers_from_login_response_headers(response)
  end
  
  context 'for Agents' do
    context 'should record Agency' do
      it 'creation' do
        post '/v2/staff_agency/agencies', params: { agency: agency_params }, headers: @headers
        result = JSON.parse response.body
        expect(response.status).to eq(201)
        expect(result["id"]).to_not eq(nil)
        agency = Agency.find result["id"]
        expect(agency.histories.count).to eq(1)
        expect(agency.histories.first.action).to eq('create')
        expect(agency.histories.first.recordable_type).to eq('Agency')
        expect(agency.histories.first.recordable_id).to eq(agency.id)
        expect(agency.histories.first.authorable_type).to eq('Staff')
        expect(agency.histories.first.authorable_id).to eq(@staff.id)
        
        login_staff(@staff)
        @headers = get_auth_headers_from_login_response_headers(response)
        get "/v2/staff_agency/agencies/#{agency.id}/histories", headers: @headers
        result = JSON.parse response.body
        expect(result.count).to eq(1)
        expect(result.first['id']).to eq(agency.histories.first.id)
      end
      
      it 'update' do
        expect(@agency.whitelabel).to eq(false)
        put "/v2/staff_agency/agencies/#{@agency.id}", params: { agency: {whitelabel: true} }, headers: @headers
        result = JSON.parse response.body
        expect(response.status).to eq(200)
        expect(result["whitelabel"]).to eq(true)
        expect(@agency.histories.last.action).to eq('update')
        expect(@agency.histories.last.recordable_type).to eq('Agency')
        expect(@agency.histories.last.recordable_id).to eq(@agency.id)
        expect(@agency.histories.last.authorable_type).to eq('Staff')
        expect(@agency.histories.last.authorable_id).to eq(@staff.id)
        expect(@agency.histories.last.data['whitelabel']['previous_value']).to eq(false)
        expect(@agency.histories.last.data['whitelabel']['new_value']).to eq(true)
        
        login_staff(@staff)
        @headers = get_auth_headers_from_login_response_headers(response)
        get "/v2/staff_agency/agencies/#{@agency.id}/histories", headers: @headers
        result = JSON.parse response.body
        expect(result.first['id']).to eq(@agency.histories.last.id)
      end
    end
    
    context 'should record Account' do
      it 'creation' do
        post '/v2/staff_agency/accounts', params: { account: account_params }, headers: @headers
        result = JSON.parse response.body
        expect(response.status).to eq(201)
        expect(result["id"]).to_not eq(nil)
        account = Account.find result["id"]
        expect(account.histories.count).to eq(1)
        expect(account.histories.first.action).to eq('create')
        expect(account.histories.first.recordable_type).to eq('Account')
        expect(account.histories.first.recordable_id).to eq(account.id)
        expect(account.histories.first.authorable_type).to eq('Staff')
        expect(account.histories.first.authorable_id).to eq(@staff.id)

        login_staff(@staff)
        @headers = get_auth_headers_from_login_response_headers(response)
        get "/v2/staff_agency/accounts/#{account.id}/histories", headers: @headers
        result = JSON.parse response.body
        expect(result.first['id']).to eq(account.histories.last.id)
      end
      
      it 'update' do
        account = FactoryBot.create(:account, agency: @agency)
        expect(account.whitelabel).to eq(false)
        put "/v2/staff_agency/accounts/#{account.id}", params: { account: {whitelabel: true} }, headers: @headers
        result = JSON.parse response.body
        expect(response.status).to eq(200)
        expect(result["whitelabel"]).to eq(true)
        expect(account.histories.last.action).to eq('update')
        expect(account.histories.last.recordable_type).to eq('Account')
        expect(account.histories.last.recordable_id).to eq(account.id)
        expect(account.histories.last.authorable_type).to eq('Staff')
        expect(account.histories.last.authorable_id).to eq(@staff.id)
        expect(account.histories.last.data['whitelabel']['previous_value']).to eq(false)
        expect(account.histories.last.data['whitelabel']['new_value']).to eq(true)
      end
    end
    
    context 'should record Claim' do
      it 'creation' do
        post '/v2/staff_agency/claims', params: { claim: claim_params(@agency) }, headers: @headers
        result = JSON.parse response.body
        expect(response.status).to eq(201)
        expect(result["id"]).to_not eq(nil)
        claim = Claim.find result["id"]
        expect(claim.histories.count).to eq(1)
        expect(claim.histories.first.action).to eq('create')
        expect(claim.histories.first.recordable_type).to eq('Claim')
        expect(claim.histories.first.recordable_id).to eq(claim.id)
        expect(claim.histories.first.authorable_type).to eq('Staff')
        expect(claim.histories.first.authorable_id).to eq(@staff.id)
        
        login_staff(@staff)
        @headers = get_auth_headers_from_login_response_headers(response)
        get "/v2/staff_agency/claims/#{claim.id}/histories", headers: @headers
        result = JSON.parse response.body
        expect(result.first['id']).to eq(claim.histories.last.id)
        
      end
      
      it 'update' do
        claim_params = claim_params(@agency)
        claim = Claim.create(claim_params)
        expect(claim.persisted?).to eq(true)
        expect(claim.subject).to eq(claim_params[:subject])
        put "/v2/staff_agency/claims/#{claim.id}", params: { claim: {subject: "New subject"} }, headers: @headers
        result = JSON.parse response.body
        expect(response.status).to eq(200)
        expect(result["subject"]).to eq('New subject')
        expect(claim.histories.last.action).to eq('update')
        expect(claim.histories.last.recordable_type).to eq('Claim')
        expect(claim.histories.last.recordable_id).to eq(claim.id)
        expect(claim.histories.last.authorable_type).to eq('Staff')
        expect(claim.histories.last.authorable_id).to eq(@staff.id)
        expect(claim.histories.last.data['subject']['previous_value']).to eq(claim_params[:subject])
        expect(claim.histories.last.data['subject']['new_value']).to eq("New subject")
      end
    end
    
    context 'should record Insurable' do
      it 'creation' do
        post '/v2/staff_agency/insurables', params: { insurable: insurable_params(FactoryBot.create(:account, agency: @agency)) }, headers: @headers
        result = JSON.parse response.body
        expect(response.status).to eq(201)
        expect(result["id"]).to_not eq(nil)
        insurable = Insurable.find result["id"]
        expect(insurable.histories.count).to eq(1)
        expect(insurable.histories.first.action).to eq('create')
        expect(insurable.histories.first.recordable_type).to eq('Insurable')
        expect(insurable.histories.first.recordable_id).to eq(insurable.id)
        expect(insurable.histories.first.authorable_type).to eq('Staff')
        expect(insurable.histories.first.authorable_id).to eq(@staff.id)
        
        login_staff(@staff)
        @headers = get_auth_headers_from_login_response_headers(response)
        get "/v2/staff_agency/insurables/#{insurable.id}/histories", headers: @headers
        result = JSON.parse response.body
        expect(result.first['id']).to eq(insurable.histories.last.id)
        
      end
      
      it 'update' do
        insurable_params = insurable_params(FactoryBot.create(:account, agency: @agency))
        insurable = Insurable.create(insurable_params)
        expect(insurable.persisted?).to eq(true)
        expect(insurable.title).to eq(insurable_params[:title])
        put "/v2/staff_agency/insurables/#{insurable.id}", params: { insurable: {title: "New subject"} }, headers: @headers
        result = JSON.parse response.body
        expect(response.status).to eq(200)
        expect(result["title"]).to eq('New subject')
        expect(insurable.histories.last.action).to eq('update')
        expect(insurable.histories.last.recordable_type).to eq('Insurable')
        expect(insurable.histories.last.recordable_id).to eq(insurable.id)
        expect(insurable.histories.last.authorable_type).to eq('Staff')
        expect(insurable.histories.last.authorable_id).to eq(@staff.id)
        expect(insurable.histories.last.data['title']['previous_value']).to eq(insurable_params[:title])
        expect(insurable.histories.last.data['title']['new_value']).to eq("New subject")
      end
    end
  end  
end 
