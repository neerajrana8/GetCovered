require 'rails_helper'
include ActionController::RespondWith

describe 'Global Agency Permission spec', type: :request do

  it 'disables permission in agency staff' do
    agency = FactoryBot.create(:agency)
    staff = FactoryBot.create(:staff, role: 'agent', organizable: agency)
    permission = agency.global_agency_permissions.permissions.keys.first

  end
end
