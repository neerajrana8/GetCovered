# Insurable Model
# file: app/models/insurable.rb

class Insurable < ApplicationRecord
  # Concerns
  include ElasticsearchSearchable
  include CarrierQbeInsurable
  include CarrierMsiInsurable
  include CoverageReport # , EarningsReport, RecordChange
  include RecordChange
  include SetSlug
  
  after_commit :create_profile_by_carrier,
    on: :create
  
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
  
  validates_presence_of :title, :slug
  validate :must_belong_to_same_account_if_parent_insurable
  validate :title_uniqueness, on: :create

  scope :covered, -> { where(covered: true) }
  scope :units, -> { where(insurable_type_id: InsurableType::UNITS_IDS) }
  scope :communities, -> { where(insurable_type_id: InsurableType::COMMUNITIES_IDS) }
  scope :buildings, -> { where(insurable_type_id: InsurableType::BUILDINGS_IDS) }

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
    cit = CarrierInsurableType.where(carrier_id: carrier_id, insurable_type_id: insurable_type_id).take
    unless cit.nil?
      carrier_insurable_profiles.create!(traits: cit.profile_traits,
                                         data: cit.profile_data,
                                         carrier_id: carrier_id)
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
  
  def buildings
    insurables.where(insurable_type_id: InsurableType::BUILDINGS_IDS)
  end
	
	def parent_community
		to_return = nil
		
		unless insurable.nil?
      if insurable_type.title.include? "Unit"
        if insurable.insurable_type.title.include? "Building"
          to_return = insurable.insurable
        else
          to_return = insurable
        end
      end	
		end
		
		return to_return
  end

  def parent_community_for_all
    to_return = nil

    if insurable.present?
      if InsurableType::UNITS_IDS.include?(insurable_type_id)
        if InsurableType::BUILDINGS_IDS.include?(insurable.insurable_type_id)
          to_return = insurable.insurable
        else
          to_return = insurable
        end
      elsif InsurableType::BUILDINGS_IDS.include?(insurable_type_id)
        to_return = insurable
      end
    end

    return to_return
  end

  def parent_building
    if insurable.present? && InsurableType::BUILDINGS_IDS.include?(insurable.insurable_type_id)
      insurable
    end
  end
	
	def community_with_buildings
    to_return = false
    
    if insurable_type.title.include? "Community"
      if insurables.count > 0
        if insurables.where(insurable_type_id: 7).count > 0
          to_return = true  
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
  
  private

  def title_uniqueness
    return if insurable.nil?
    if insurable.insurables.where(title: title, insurable_type: insurable_type).any?
      errors.add(:title, 'should be uniq inside group')
    end
  end
    
    def create_profile_by_carrier
      if insurable_type.title.include? "Residential"
        carrier_profile(1)
      else
        carrier_profile(3)
      end  
    end
    
end
