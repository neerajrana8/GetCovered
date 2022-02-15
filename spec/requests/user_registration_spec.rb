require 'rails_helper'
include ActionController::RespondWith
ActiveJob::Base.queue_adapter = :test

describe 'User registraion spec', type: :request do
  let(:user_params) { { email: 'test@getcovered.com', password: 'foobar', password_confirmation: 'foobar' } }
  def create_user(params)
    post '/v2/user/auth', params: params.to_json, headers: { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' }
  end
  
  it 'should create user with valid params and enqueue Invitation job' do
    expect { create_user(user_params) }.to change { User.count }.by(1)

    result = JSON.parse response.body
    expect(response.has_header?('access-token')).to eq(true)
    expect(result['email']).to eq(user_params['email'])
  end
  
  it 'should return error' do
    invalid_params = { email: nil, password: 'foobar' }
    expect { create_user(invalid_params) }.to_not change { User.count }
    result = JSON.parse response.body
    expect(response.status).to eq(422)
    expect(result['error']).to eq('user_creation_error')
  end
end
