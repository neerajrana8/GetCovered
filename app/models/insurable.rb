# Insurable Model
# file: app/models/insurable.rb

class Insurable < ApplicationRecord
  # Concerns
  include ElasticsearchSearchable
  include CarrierQbeInsurable
  include CarrierMsiInsurable
  include CarrierDcInsurable
  include CoverageReport # , EarningsReport, RecordChange
  include RecordChange
  include SetSlug
  
  before_save :refresh_policy_type_ids
  
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

  accepts_nested_attributes_for :addresses, allow_destroy: true
  
  enum category: %w[property entity]
  
  validates_presence_of :title, :slug
  validate :must_belong_to_same_account_if_parent_insurable
  validate :title_uniqueness, on: :create

  scope :covered, -> { where(covered: true) }
  scope :units, -> { where(insurable_type_id: InsurableType::UNITS_IDS) }
  scope :communities, -> { where(insurable_type_id: InsurableType::COMMUNITIES_IDS) }
  scope :buildings, -> { where(insurable_type_id: InsurableType::BUILDINGS_IDS) }
  scope :communities_and_buildings, -> { where(insurable_type_id: InsurableType::COMMUNITIES_IDS | InsurableType::BUILDINGS_IDS) }

  %w[Residential Commercial].each do |major_type|
    %w[Community Unit].each do |minor_type|
      scope "#{major_type.downcase}_#{minor_type.downcase.pluralize}".to_sym, -> { joins(:insurable_type).where("insurable_types.title = '#{major_type} #{minor_type}'") }
    end
  end
  

  def self.find_from_address(address, extra_query_params = {}, allow_multiple: true)
    # search for the insurable
    results = Insurable.references(:address).includes(:addresses).where({
      addresses: { primary: true, street_number: address.street_number, street_name: address.street_name, city: address.city, state: address.state, zip_code: address.zip_code }
    }.merge(extra_query_params || {}))
    unless allow_multiple
      results = case results.count; when 0; nil; when 1; results.take; else; results.find{|i| i.primary_address.street_two == address.street_two }; end
    end
    return results
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
		to_return = []
		
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

  def unit?
    InsurableType::UNITS_IDS.include?(insurable_type_id)
  end
  
  def refresh_policy_type_ids(and_save: false)
    my_own_little_agency = (self.agency_id ? ::Agency.where(id: self.agency_id).take : nil) || self.account&.agency || nil
    if my_own_little_agency.nil? || self.primary_address.nil?
      self.policy_type_ids = []
    else
      self.policy_type_ids = CarrierAgencyAuthorization.where(carrier_agency: my_own_little_agency.carrier_agencies, state: self.primary_address&.state, available: true)
                                                       .order("policy_type_id").group("policy_type_id").pluck("policy_type_id")
      self.policy_type_ids &= self.insurable_type.policy_type_ids
    end
    if and_save
      self.save
    end
  end


      
            
  def self.get_or_create(
    address: nil,                 # an address string (required unless unit title and insurable_id provided)
    unit: nil,                    # true to search for units, false to search for buildings/communities, a string to search for a specific unit title; nil means search for a unit if address has line 2 and a community otherwise
    insurable_id: nil,            # optional; the community/building the sought insurable must belong to
    create_if_ambiguous: false,   # pass true to force insurable creation if there's any ambiguity (example: if you've already called this and got 'multiple' type results, none of which were what you wanted)
    disallow_creation: false,     # pass true to ONLY query, NOT create
    created_community_title: nil, # optionally pass the title for the community in case we have to create it (defaults to combined_street_address)
    account_id: nil               # optionally, the account id to use if we create anything
  )
    # validate params
    if address.nil? && ([true,false,nil].include?(unit) || insurable_id.nil?)
      raise ArgumentError.new("either 'address' or 'insurable_id' and a string 'unit' must be provided")
    end
    # if we have a unit title and an insurable id, get or create the unit without dealing with address nonsense
    unit_title = [true,false,nil].include?(unit) ? nil : unit
    if !unit_title.blank? && !insurable_id.nil?
      results = ::Insurable.where(title: unit_title, insurable_id: insurable_id, insurable_type_id: ::InsurableType::RESIDENTIAL_UNITS_IDS)
      case results.count
        when 0
          return nil if disallow_creation
          results = ::Insurable.where(id: insurable_id, insurable_type_id: ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS | ::InsurableType::RESIDENTIAL_BUILDINGS_IDS).take
          if results.blank?
            return { error_type: :invalid_community, message: "The requested residential building/community id does not exist" }
          end
          community = (results.parent_community || results)
          if community.preferred_ho4
            return { error_type: :invalid_unit, message: "The requested unit does not exist" }
          end
          unit = results.insurables.new(
            title: unit_title,
            insurable_type: ::InsurableType.where(title: "Residential Unit").take,
            enabled: true, category: 'property', preferred_ho4: false,
            account_id: result.account_id || community.account_id || nil # MOOSE WARNING: nil account id allowed?
          )
          unless unit.save
            return { error_type: :invalid_unit, message: "Unable to create unit", details: unit.errors.full_messages }
          end
          return unit
        when 1
          return results.first
        else
          return results.to_a
      end
    end
    # get a valid address model if possible
    if address.class == ::Address
      unless address.valid?
        return { error_type: :invalid_address, message: "Invalid address value", details: address.errors.full_messages }
      end
    else
      address = ::Address.from_string(address)
      unless address.errors.blank?
        return { error_type: :invalid_address, message: "Invalid address value", details: address.errors.full_messages }
      end
    end
    # try to figure out unit title if applicable
    seeking_unit = unit ? true : unit.nil? ? !address.street_two.blank? : false
    if seeking_unit
      if unit_title.blank? && !address.street_two.blank?
        splat = address.street_two.gsub('#', ' ').gsub('.', ' ')
                                  .gsub(/\s+/m, ' ').gsub(/^\s+|\s+$/m, '')
                                  .split(" ").select do |strang|
                                    ![
                                      'apartment', 'apt', 'unit',
                                      'flat', 'room', 'office',
                                      'no', 'number'
                                    ].include?(strang.lcase)
                                  end
        if splat.size == 1
          unit_title = splat[0]
        end
      end
    end
    # search for the insurable
    if seeking_unit # we want a unit
      if unit_title.nil?
        return { error_type: :invalid_address_line_two, message: "Unable to deduce unit title from address", details: "'#{address.line_two}' is not a standard format (e.g. 'Apartment #2, Unit 3, #5, etc.)" }
      end
      # query for units of the appropriate title, address, and, if provided, insurable_id
      parent_ids = ::Insurable.references(:address).includes(:addresses).where(
        {
          addresses: {
            primary: true, 
            street_number: address.street_number,
            street_name: address.street_name,
            city: address.city,
            state: address.state,
            zip_code: address.zip_code
          },
          insurable_type_id: ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS | ::InsurableType::RESIDENTIAL_BUILDINGS_IDS | ::InsurableType::RESIDENTIAL_UNITS_IDS
        }
      ).order(:id).group(:id).pluck(:id)
      results = nil
      if !insurable_id.nil?
        parent_ids = parent_ids & [insurable_id]
        results = ::Insurable.where({
          title: unit_title,
          insurable_type_id: ::InsurableType::RESIDENTIAL_UNITS_IDS,
          insurable_id: parent_ids
        })
      else
        results = ::Insurable.where({
          title: unit_title,
          insurable_type_id: ::InsurableType::RESIDENTIAL_UNITS_IDS,
          insurable_id: parent_ids
        }).or(::Insurable.where({ # gotta account for the possibility that a standalone-addressed unit came up in our initial query
          id: parent_ids,
          title: unit_title,
          insurable_type_id: ::InsurableType::RESIDENTIAL_UNITS_IDS
        }))
      end
      # handle the units returned by the query
      case results.count
        when 0
          # unit does not exist; find a parent we can create on
          return nil if disallow_creation
          parents = ::Insurable.where(id: parent_ids, insurable_type_id: ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS | ::InsurableType::RESIDENTIAL_BUILDINGS_IDS)
          parent = parents.select{|p| (p.parent_community || p).preferred_ho4 == false }.sort{|a,b| (::InsurableType::RESIDENTIAL_BUILDINGS_IDS.include?(a) ? -1 : 1) <=> (::InsurableType::RESIDENTIAL_BUILDINGS_IDS.include?(b) ? -1 : 1) }.first
          if parent.nil?
            # flee if prevented from creating community
            if disallow_creation
              return nil
            elsif !insurable_id.nil?
              return { error_type: :invalid_community, message: "The requested residential building/community id does not exist" }
            elsif parents.count > 0 # if parents.count > 0, we found the community/building but it was preferred
              return { error_type: :invalid_unit, message: "The requested unit does not exist" }
            end
            # create community
            address.id = nil
            address.primary = true
            address.street_two = nil
            parent = ::Insurable.new(
              title: address.combined_street_address,
              insurable_type: ::InsurableType.where(title: "Residential Community").take,
              enabled: true, preferred_ho4: false, category: 'property',
              addresses: [ address ],
              account_id: nil # MOOSE WARNING: nil account_id???
            )
            unless parent.save
             return { error_type: :invalid_community, message: "Unable to create community from address", details: parent.errors.full_messages }
            end
          end
          # create the unit
          unit = results.insurables.new(
            title: unit_title,
            insurable_type: ::InsurableType.where(title: "Residential Unit").take,
            enabled: true, category: 'property', preferred_ho4: false,
            account_id: parent.account_id || nil # MOOSE WARNING: nil account id allowed?
          )
          unless unit.save
            return { error_type: :invalid_unit, message: "Unable to create unit", details: unit.errors.full_messages }
          end
          return unit
        when 1
          # we found the unit
          return results.first
        else
          # we found multiple candidate units
          return results.to_a
      end
    else # we want a community (or building)
      results = ::Insurable.references(:address).includes(:addresses).where(
        {
          addresses: {
            primary: true, 
            street_number: address.street_number,
            street_name: address.street_name,
            city: address.city,
            state: address.state,
            zip_code: address.zip_code
          },
          insurable_type_id: ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS | ::InsurableType::RESIDENTIAL_BUILDINGS_IDS,
          insurable_id: insurable_id
        }.compact
      )
      unless address.street_two.blank?
        with_street_two = results.select{|res| res.primary_address.street_two.strip == address.street_two.strip }
        case with_street_two.count
          when 0
            # we can create a community with the exact specified line 2, or we can drop back to the blank street two block and return the partial matches
            if create_if_ambiguous || results.count == 0
              results = [] # force results count to be empty so we fall through and end up creating
            elsif results.count == 1
              return results.to_a # single result, but non-definitive, so still in an array
            end
          when 1
            return with_street_two[0]
          else
            return with_street_two.to_a
        end
      end
      case results.count
        when 0
          return nil if disallow_creation
          # try to get parent if applicable
          parent = nil
          unless insurable_id.nil?
            parent = ::Insurable.where(id: insurable_id, insurable_type_id: ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS).take
            if parent.nil?
              return { error_type: :invalid_building, message: "Requested parent community does not exist" }
            elsif parent.preferred_ho4
              return { error_type: :invalid_building, message: "Requested building does not exist" }
            else
              parent_address = parent&.primary_address
              if parent_address.state != address.state || parent_address.zip_code != address.zip_code || parent_address.city != address.city
                return { error_type: :invalid_building, message: "Requested parent community is not in the same state/zip/city" }
              end
            end
          end
          # create community (or building, if there was a parent provided)
          address.id = nil
          address.primary = true
          created = ::Insurable.new(
              title: created_created_title || address.combined_street_address,
              insurable_type: ::InsurableType.where(title: parent.nil? ? "Residential Community" : "Residential Building").take,
              enabled: true, preferred_ho4: false, category: 'property',
              addresses: [ address ],
              account_id: parent&.account_id || nil # MOOSE WARNING: nil account_id???
            )
          unless created.save
           return { error_type: :"invalid_#{parent.nil? ? 'community' : 'building'}", message: "Unable to create #{parent.nil? ? 'community' : 'building'} from address", details: created.errors.full_messages }
          end
          return created
        when 1
          return results.first
        else
          return results.to_a
      end
    end
    # every possible case resulted in a return already
    return { error_type: :internal_error, message: "Internal error occurred" }
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
