require 'rails_helper'
include ActionController::RespondWith

describe 'User API spec', type: :request do
  before :all do
    @user = create_user
  end
  
  before :each do
    login_user(@user)
    @headers = get_auth_headers_from_login_response_headers(response)
  end
  
  it 'should not update password for another user' do
    second_user = create_user
    put change_password_v2_user_path(second_user), params: correct_password_params, headers: @headers
    result = JSON.parse response.body
    expect(response.status).to eq(401)
    expect(result["errors"]).to eq(["Unauthorized Access"])
  end
  
  
  it 'should update password' do
    put change_password_v2_user_path(@user), params: correct_password_params, headers: @headers
    result = JSON.parse response.body
    expect(response.status).to eq(200)
    expect(result["id"]).to eq(@user.id)
  end
  
  it 'should not update password with incorrect password' do
    incorrect_password_params = { 
      user: {
        current_password: 'wrong password',
        password: 'foobar',
        password_confirmation: 'foobar'
      }
    }
    put change_password_v2_user_path(@user), params: incorrect_password_params, headers: @headers
    result = JSON.parse response.body
    expect(response.status).to eq(422)
    expect(result["errors"]).to eq({"current_password"=>["is invalid"]})
  end
  
  # context 'for StaffAccount role' do
  #   before :all do
  #     User.create(email: "newtest@getcovered.com")
  #     @staff = create_account_for FactoryBot.create(:agency)
  #   end
  #
  #   before :each do
  #     login_staff(@staff)
  #     @headers = get_auth_headers_from_login_response_headers(response)
  #   end
  #
  #   it 'should autocomplete search users by email' do
  #     user = ::User.create(email: 'newemail@test.com', password: 'foobar')
  #     ::User.__elasticsearch__.refresh_index!
  #     get search_v2_users_path, params: {"query" => 'newemail'}, headers: @headers
  #     result = JSON.parse response.body
  #     expect(result).not_to be_empty
  #     expect(result.first["id"]).to eq(user.id)
  #   end
  # end
  
  
  def correct_password_params
    { 
      user: {
        current_password: 'test1234',
        password: 'foobar',
        password_confirmation: 'foobar'
      }
    }
  end
  
end 
