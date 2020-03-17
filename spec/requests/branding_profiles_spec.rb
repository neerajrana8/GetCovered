require 'rails_helper'
include ActionController::RespondWith

describe 'Branding Profiles API spec', type: :request do
  before :all do
    @agency = FactoryBot.create(:agency)
    @staff = FactoryBot.create(:staff)
    
  end
  
  it 'should work' do
    puts @agency.inspect
  end
  
end