# Integration Model
# file: app/models/integration.rb

class Integration < ApplicationRecord
  belongs_to :integratable, polymorphic: true
  has_many :integration_profiles

  enum provider: %w[yardi realpage engrain]

  validate :one_provider_per_integratable

  private
  def one_provider_per_integratable
    errors.add(:integratable, "#{ integratable.title } already has a #{ self.provider.titlecase } integration") if integratable.integrations.exists?(provider: self.provider)
  end
end
