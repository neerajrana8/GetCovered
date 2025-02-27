# == Schema Information
#
# Table name: integrations
#
#  id                :bigint           not null, primary key
#  external_id       :string
#  credentials       :jsonb
#  configuration     :jsonb
#  enabled           :boolean          default(FALSE)
#  integratable_type :string
#  integratable_id   :bigint
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  provider          :integer          default("yardi")
#
# Integration Model
# file: app/models/integration.rb

class Integration < ApplicationRecord
  belongs_to :integratable, polymorphic: true
  has_many :integration_profiles
  
  before_save :clear_history
  
  validate :one_provider_per_integratable

  enum provider: %w[yardi realpage engrain]
  
  YARDI_TCODE_CHANGERS = ["User", "LeaseUser", "PolicyUser"].freeze # these are the IntegrationProfile profileable_type values for folk that need to be updated upon a tcode change
  
  def set_nested(value, *keys, field: 'configuration')
    dude = self.send(field)
    last_key = keys.pop
    keys.each{|k| dude = (dude[k] ||= {}) }
    dude[last_key] = value
  end
  
  def get_nested(*keys, field: 'configuration')
    self.send(field).dig(*keys)
  end

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
