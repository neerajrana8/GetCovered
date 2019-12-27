# Agency model
# file: app/models/agency.rb
#
# An agency is an entity capable of issuing insurance policies on behalf of an
# insurance Carrier.  The agency is managed by staff who have been assigned the 
# Agency in their organizable relationship.

class Agency < ApplicationRecord
  # Concerns
  include ElasticsearchSearchable
  include SetSlug
  include SetCallSign
  include CoverageReport
  include EarningsReport

  # Active Record Callbacks
  after_initialize :initialize_agency
  
  # belongs_to relationships
  belongs_to :agency,
    optional: true
    
  has_many :agencies
  
  # has_many relationships
  has_many :carrier_agencies
  has_many :carriers,
    through: :carrier_agencies
  has_many :carrier_agency_authorizations,
    through: :carrier_agencies
    
  has_many :accounts
  has_many :insurables, through: :accounts
  has_many :insurable_rates
  has_many :leases, through: :accounts
  has_many :insurable_rates
  has_many :staff,
    as: :organizable
      
  has_many :account_staff,
    through: :accounts,
    as: :organizable,
    source: :staff,
    class_name: 'Staff'
      
  has_many :policies
  has_many :claims, through: :policies

  has_many :policy_applications
  has_many :policy_quotes
    
  has_many :branding_profiles,
    as: :profileable

  has_many :commission_strategies, as: :commissionable
  
  has_many :commissions, as: :commissionable

  has_many :billing_strategies
      
  has_many :fees,
    as: :ownerable
  
  has_many :events,
    as: :eventable
  
  has_many :addresses,
    as: :addressable,
    autosave: true

  has_many :reports,
    as: :reportable

  has_many :active_account_users,
    through: :accounts

  has_many :active_users,
    through: :active_account_users,
    source: :user

  accepts_nested_attributes_for :addresses

  scope :enabled, -> { where(enabled: true) }

  # ActiveSupport +pluralize+ method doesn't work correctly for this word(returns staffs). So I added alias for it
  alias staffs staff
  
  def owner
    staff.where(id: staff_id).take
   end
  
  def primary_address
    addresses.where(primary: true).take 
   end
  
  # Agent.provides(policy_type_id)
  # checks to see if agent is authorized for a policy type
  # in a state and zipcode
  #
  # Example:
  #   @agency = Agency.find(1)
  #   @agency.provides?(1, "CA")
  #   => true / false
  
  def offers_policy_type_in_region(args = {})
    result = false
    requirements_check = false
    
    opts = {
      carrier_id: nil,
      policy_type_id: nil,
      state: nil,
      zip_code: nil,
      plus_four: nil
    }.merge!(args)
    
    opts.keys.each do |k|
      unless k == :plus_four
        requirements_check = opts[k].nil? ? false : true
        break if requirements_check == false
      end
    end
    
    if requirements_check
      carrier = Carrier.find(opts[:carrier_id])
      if carrier.carrier_policy_types.exists?(policy_type_id: opts[:policy_type_id])
        carrier_availability = carrier.carrier_policy_type_availabilities.where(state: opts[:state], available: true).take
        agency_availability = carrier.carrier_agency_authorizations.where(agency_id: id, state: opts[:state], available: true).take
        
        unless carrier_availability.nil? || 
               agency_availability.nil?
               
          result = carrier_availability.on_blacklist?(opts[:zip_code], opts[:plus_four]) &&
            agency_availability.on_blacklist?(opts[:zip_code], opts[:plus_four]) ? false : true
        end
        
      end
    end  
    result
  end
  
  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :title, type: :text, analyzer: 'english'
      indexes :call_sign, type: :text, analyzer: 'english'
    end
  end
  
  private
    
  def initialize_agency
   # Blank for now...
 end
end
