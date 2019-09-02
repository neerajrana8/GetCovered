# Insurable Model
# file: app/models/insurable.rb

class Insurable < ApplicationRecord
  # Concerns
  include CarrierQbeInsurable, ElasticsearchSearchable#, EarningsReport, RecordChange
  
  belongs_to :account
  belongs_to :insurable, optional: true
  belongs_to :insurable_type
  
  has_many :insurables
  has_many :carrier_insurable_profiles
  has_many :insurable_rates
  
  has_many :policy_insurables
  has_many :policies, through: :policy_insurables
  has_many :policy_applications, through: :policy_insurables
  
  has_many :events, as: :eventable
  
  has_many :assignments, as: :assignable
  has_many :staffs, through: :assignments
  
  has_many :leases
  
  has_many :addresses, as: :addressable, autosave: true
  
  accepts_nested_attributes_for :addresses
  
  enum category: ['property', 'entity']
  
  validate :must_belong_to_same_account_if_parent_insurable
  
  
  ['Residential', 'Commercial'].each do |major_type|
    ['Community', 'Unit'].each do |minor_type|
      scope "#{ major_type.downcase }_#{ minor_type.downcase.pluralize }".to_sym, -> { joins(:insurable_type).where("insurable_types.title = '#{ major_type } #{ minor_type }'") }
    end
  end
  
  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :title, type: :text, analyzer: 'english'
    end
  end
  # Insurable.primary_address
  #
  
  def primary_address
    if addresses.count == 0
      return !insurable.nil? ? insurable.primary_address() : 
      addresses.where(primary: true).take
    else
      return addresses.where(primary: true).take
    end
  end
  
  # Insurable.primary_staff
  #
  
  def primary_staff
    assignment = assignments.where(primary: true).take
    return assignment.staff.nil? ? nil : assignment.staff
  end
  
  # Insurable.create_carrier_profile(carrier_id)
  #
  
  def create_carrier_profile(carrier_id)
    carrier = Carrier.find(carrier_id)
    if !carrier.nil? && carrier.carrier_insurable_types
      .exists?(insurable_type: insurable_type)
      carrier_insurable_type = carrier.carrier_insurable_types
      .where(insurable_type: insurable_type).take
      self.carrier_insurable_profiles.create!(traits: carrier_insurable_type.profile_traits, 
      data: carrier_insurable_type.profile_data,
      carrier: carrier)
    end  	
  end
  
  # Insurable.carrier_profile(carrier_id)
  #
  
  def carrier_profile(carrier_id)
    unless carrier_id.nil?
      return carrier_insurable_profiles.where(carrier_id: carrier_id).take 
    end
  end
  
  def must_belong_to_same_account_if_parent_insurable
    return if insurable.nil?

    errors.add(:account, "must belong to same account as parent") if insurable.account != self.account
  end
  
end
