# Integration Profile Model
# file: app/models/integration_profile.rb

class IntegrationProfile < ApplicationRecord
  belongs_to :integration
  belongs_to :profileable, polymorphic: true
  
  # profileable expansions
  belongs_to :insurable, optional: true, foreign_key: 'profileable_id', -> { where(integration_profiles: { profileable_type: 'Insurable' }) }
  belongs_to :lease, optional: true, foreign_key: 'profileable_id', -> { where(integration_profiles: { profileable_type: 'Lease' }) }
  belongs_to :policy, optional: true, foreign_key: 'profileable_id', -> { where(integration_profiles: { profileable_type: 'Policy' }) }
  belongs_to :user, optional: true, foreign_key: 'profileable_id', -> { where(integration_profiles: { profileable_type: 'User' }) }
end
