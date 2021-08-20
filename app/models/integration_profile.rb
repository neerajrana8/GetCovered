class IntegrationProfile < ApplicationRecord
  belongs_to :profileable, polymorphic: true
end
