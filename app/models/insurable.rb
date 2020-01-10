# Insurable Model
# file: app/models/insurable.rb

class Insurable < ApplicationRecord
  # Concerns
  include ElasticsearchSearchable
  include CarrierQbeInsurable
  include CoverageReport # , EarningsReport, RecordChange
  
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

  has_many :reports, as: :reportable

  has_many :histories, as: :recordable
  
  accepts_nested_attributes_for :addresses
  
  enum category: %w[property entity]
  
  validate :must_belong_to_same_account_if_parent_insurable

  scope :covered, -> { where(covered: true) }
  
  %w[Residential Commercial].each do |major_type|
    %w[Community Unit].each do |minor_type|
      scope "#{major_type.downcase}_#{minor_type.downcase.pluralize}".to_sym, -> { joins(:insurable_type).where("insurable_types.title = '#{major_type} #{minor_type}'") }
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
    if addresses.count.zero?
      return insurable.primary_address unless insurable.nil?
    else
      addresses.find_by(primary: true)
    end
  end
  
  # Insurable.primary_staff
  #
  
  def primary_staff
    assignment = assignments.find_by(primary: true)
    assignment.staff.nil? ? nil : assignment.staff
  end
  
  # Insurable.create_carrier_profile(carrier_id)
  #
  
  def create_carrier_profile(carrier_id)
    carrier = Carrier.find(carrier_id)
    if !carrier.nil? && carrier.carrier_insurable_types
        .exists?(insurable_type: insurable_type)
      carrier_insurable_type = carrier.carrier_insurable_types
        .find_by(insurable_type: insurable_type)
      carrier_insurable_profiles.create!(traits: carrier_insurable_type.profile_traits, 
                                         data: carrier_insurable_type.profile_data,
                                         carrier: carrier)
    end    
  end
  
  # Insurable.carrier_profile(carrier_id)
  #
  
  def carrier_profile(carrier_id)
    return carrier_insurable_profiles.where(carrier_id: carrier_id).take unless carrier_id.nil?
  end
  
  def must_belong_to_same_account_if_parent_insurable
    return if insurable.nil?
    
    errors.add(:account, 'must belong to same account as parent') if insurable.account != account
  end
  
  def units
		to_return = nil
		
		unless insurable_type.title.include? "Unit"
			if insurables.count > 0
				if insurables.where(insurable_type_id: [4,5]).count > 0
					to_return = insurables
				elsif insurables.where(insurable_type_id: 7).count > 0
					to_return = []
					insurables.each { |i| to_return.push(*i.insurables) }
				end
			end
		end  
		
		return to_return
	end
  
  def authorized_to_provide_for_address?(carrier_id, policy_type_id)
    authorized = false
    addresses.each do |address|
      return true if authorized == true

      args = { 
        carrier_id: carrier_id,
        policy_type_id: policy_type_id,
        state: address.state,
        zip_code: address.zip_code,
        plus_four: address.plus_four
      }
      authorized = account.agency.offers_policy_type_in_region(args)
    end
    authorized
  end
end
