describe 'Reset password API', type: :request do
  shared_examples 'scenarios' do
    it 'should reset for the registered entity' do
      # Get a link
      binding.pry
      # /v2/staff/auth/sign_in
      # /v2/user/auth/sign_in
      post("/v2/#{entity_type}/auth/password", params: { 'email': entity.email, "redirect_url": '/login' }.to_json, headers: base_headers)
      expect(response.status).to be(200)

      last_mail = Nokogiri::HTML(ActionMailer::Base.deliveries.last.html_part.body.decoded)
      url = last_mail.css('tbody a').first['href']
      expect(url).to be_present
      base_url, _, token = url.rpartition('/')
      expect(base_url).to eq("#{Rails.application.credentials.uri[ENV['RAILS_ENV'].to_sym][client]}/auth/reset-password")

      # Reset the password
      put("/v2/#{entity_type}/auth/password", params: params.merge({reset_password_token: token}).to_json, headers: base_headers)
      expect(response.status).to be(200)

      # Login with an old password
      send("login_#{entity_type}", entity)
      expect(response.status).to be(401)

      # Login with a new password
      send("login_#{entity_type}", entity, password: 'tomato')
      expect(response.status).to be(200)
      expect(JSON.parse(response.body)['email']).to eq(entity.email)
    end

    it 'should return 404 for the not existing entity' do
      post("/v2/#{entity_type}/auth/password", params: { 'email': 'not@exists.com', "redirect_url": '/login' }.to_json, headers: base_headers)
      expect(response.status).to be(404)
    end
  end

  #describe 'for user' do
  #  let!(:entity) { FactoryBot.create(:user, :accepted) }
  #  let(:entity_type) { 'user' }
  #  let(:client) { :client }
  #  let(:params) { { password: 'tomato', password_confirmation: 'tomato'} }

  #  include_examples 'scenarios'
  #end

  describe 'for staffs' do
    let!(:entity) { FactoryBot.create(:staff, role: 'staff') }
    let(:entity_type) { 'staff' }
    let(:client) { :admin }
    let(:params) do
      {
        password: 'tomato',
        password_confirmation: 'tomato'
      }
    end

    it 'should return' do
      binding.pry
    end

    #include_examples 'scenarios'
  end
end
