# Integration Profile Model
# file: app/models/integration_profile.rb

class IntegrationProfile < ApplicationRecord
  belongs_to :integration
  belongs_to :profileable, polymorphic: true
end
