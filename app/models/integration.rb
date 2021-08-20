# Integration Model
# file: app/models/integration.rb

class Integration < ApplicationRecord
  belongs_to :integratable, polymorphic: true
  has_many :integration_profiles

  enum provider: %w[yardi realpage engrain]
end
