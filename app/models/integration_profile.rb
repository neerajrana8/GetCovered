# Integration Profile Model
# file: app/models/integration_profile.rb

class IntegrationProfile < ApplicationRecord
  belongs_to :integration
  belongs_to :profileable, polymorphic: true
  
  # profileable expansions for convenient joins
  has_one :self_reference, class_name: 'IntegrationProfile', foreign_key: :id
  has_one :insurable, through: :self_reference, source: :profileable, source_type: 'Insurable'
  has_one :lease, through: :self_reference, source: :profileable, source_type: 'Lease'
  has_one :policy, through: :self_reference, source: :profileable, source_type: 'Policy'
  has_one :user, through: :self_reference, source: :profileable, source_type: 'User'
end
