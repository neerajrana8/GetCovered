# Integration Model
# file: app/models/integration.rb

class Integration < ApplicationRecord
  belongs_to :integratable, polymorphic: true
  has_many :integration_profiles
  
  before_save :clear_history
  
  validate :one_provider_per_integratable

  enum provider: %w[yardi realpage engrain]

  private

  def one_provider_per_integratable
    if integratable.integrations.where.not(id: id).exists?(provider: self.provider)
      errors.add(:integratable, "#{ integratable.title } already has a #{ self.provider.titlecase } integration")
    end
  end
  
  def clear_history
    unless self.configuration&.[]('sync')&.[]('sync_history').blank?
      self.configuration['sync']['sync_history'] = []
    end
  end
end
