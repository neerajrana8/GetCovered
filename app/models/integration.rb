# Integration Model
# file: app/models/integration.rb

class Integration < ApplicationRecord
  belongs_to :integratable, polymorphic: true
  has_many :integration_profiles

  enum provider: %w[yardi realpage engrain]

  validate :one_provider_per_integratable

  private

  def one_provider_per_integratable
    if integratable.integrations.where.not(id: id).exists?(provider: self.provider)
      errors.add(:integratable, "#{ integratable.title } already has a #{ self.provider.titlecase } integration")
    end
  end
end
