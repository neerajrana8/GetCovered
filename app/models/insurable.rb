# == Schema Information
#
# Table name: insurables
#
#  id                       :bigint           not null, primary key
#  title                    :string
#  slug                     :string
#  enabled                  :boolean          default(FALSE)
#  account_id               :bigint
#  insurable_type_id        :bigint
#  insurable_id             :bigint
#  category                 :integer          default("property")
#  covered                  :boolean          default(FALSE)
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  agency_id                :bigint
#  policy_type_ids          :bigint           default([]), not null, is an Array
#  preferred_ho4            :boolean          default(FALSE), not null
#  confirmed                :boolean          default(TRUE), not null
#  occupied                 :boolean          default(FALSE)
#  expanded_covered         :jsonb            not null
#  preferred                :jsonb
#  additional_interest      :boolean          default(FALSE)
#  additional_interest_name :string
#  minimum_liability        :integer
#
# Insurable Model
# file: app/models/insurable.rb

class Insurable < ApplicationRecord
  # Concerns
  include CarrierQbeInsurable
  include CarrierMsiInsurable
  include CarrierDcInsurable
  include CoverageReport # , EarningsReport, RecordChange
  include RecordChange
  include SetSlug
  include ExpandedCovered

  before_validation :set_confirmed_automatically
  before_save :flush_parent_insurable_id, :if => Proc.new { |ins| ::InsurableType::COMMUNITIES_IDS.include?(ins.insurable_type_id) }
  before_save :refresh_policy_type_ids

  after_commit :create_profile_by_carrier,
    on: :create

  # NOTE: Disable according to #GCVR2-768 Master Policy Fixes
  # NOTE: Master policy assignment moved to MasterCoverageSweepJob
  after_create :assign_master_policy

  belongs_to :account, optional: true
  belongs_to :agency, optional: true

  belongs_to :insurable, optional: true
  belongs_to :insurable_type

  has_one :insurable_data, dependent: :destroy

  has_many :insurables
  has_many :carrier_insurable_profiles
  has_many :insurable_rates

  has_many :policy_insurables
  has_many :policies, through: :policy_insurables
  has_many :policy_applications, through: :policy_insurables

  has_many :master_policy_configurations, as: :configurable

  has_many :events, as: :eventable

  has_many :assignments, as: :assignable
  has_many :staffs, through: :assignments

  has_many :leases

  has_many :addresses, as: :addressable, autosave: true

  has_many :reports, as: :reportable

  has_many :histories, as: :recordable

  has_many :integration_profiles,
           as: :profileable
  
  has_many :insurable_rate_configurations,
           as: :configurable

  has_many :coverage_requirements

  accepts_nested_attributes_for :addresses, allow_destroy: true

  enum category: %w[property entity]

  enum special_status: {
    none: 0,
    affordable: 1
  }, _prefix: true

  #validates_presence_of :title, :slug WARNING: THIS IS DISABLED TO ALLOW TITLELESS NONPREFERRED UNITS!

  validate :must_belong_to_same_account_if_parent_insurable
  validate :title_uniqueness, on: :create

  scope :covered, -> { where(covered: true) }
  scope :confirmed, -> { where(confirmed: true) }
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

  #settings index: { number_of_shards: 1 } do
  #  mappings dynamic: 'false' do
  #    indexes :title, type: :text, analyzer: 'english'
  #  end
  #end
  
  # returns carrier status, which may differ by carrier; for MSI and QBE, it returns :preferred or :nonpreferred
  def get_carrier_status(carrier, refresh: nil)
    carrier = case carrier
      when ::Integer
        case carrier
          when ::MsiService.carrier_id;             'msi'
          when ::QbeService.carrier_id;             'qbe'
          when ::DepositChoiceService.carrier_id;   'dc'
          when ::PensioService.carrier_id;          'pensio'
          else;                                     Carrier.where(id: carrier).take&.integration_designation
        end
      when ::String;                                carrier
      when ::Carrier;                               carrier.integration_designation
      else;                                         nil
    end
    self.respond_to?("#{carrier}_get_carrier_status") ? self.send("#{carrier}_get_carrier_status", **{ refresh: refresh }.compact) : nil
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
  def create_carrier_profile(carrier_id, data: nil, traits: nil)
    cit = CarrierInsurableType.where(carrier_id: carrier_id, insurable_type_id: insurable_type_id).take
    unless cit.nil?
      carrier_insurable_profiles.create!(traits: cit.profile_traits&.send(*(traits.blank? ? [:itself] : [:merge, traits])),
                                         data: cit.profile_data&.send(*(data.blank? ? [:itself] : [:merge, data])),
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
    errors.add(:account, I18n.t('insurable_model.must_belong_to_same_account')) if insurable.account && account && insurable.account != account
  end
  
  def residential_units
    units(unit_type_ids: [4])
  end
  
  def commercial_units
    units(unit_type_ids: [5])
  end
  
  def units(unit_type_ids: [4,5])
    # special logic in case we haven't been saved yet
    if self.id.nil?
      nonunit_parents = []
      found = [self]
      while !found.blank?
        nonunit_parents.concat(found)
        found = found.map{|fi| fi.insurables.select{|i| !unit_type_ids.include?(i.insurable_type_id) } }.flatten
      end
      return nonunit_parents.map{|fi| fi.insurables.select{|i| unit_type_ids.include?(i.insurable_type_id) } }.flatten
    end
    # WARNING: at some point, we can use an activerecord callback to store all nonunit child insurable ids in a field and thus skip the loop
    # get ids of self and child insurables that might hold units
    nonunit_parent_ids = []
    found = [self.id]
    while !found.blank?
      nonunit_parent_ids.concat(found)
      found = ::Insurable.where(insurable_id: found).where.not(id: nonunit_parent_ids).where.not(insurable_type_id: unit_type_ids).order(:id).group(:id).pluck(:id)
    end
    # return the units
    return ::Insurable.where(insurable_type_id: unit_type_ids, insurable_id: nonunit_parent_ids) # WARNING: some code (msi insurable concern) expects query rather than array output here (uses scopes on this call)
  end
  
  def query_for_full_hierarchy(exclude_self: false)
    # WARNING: at some point, we can use an activerecord callback to store all nonunit child insurable ids in a field and thus skip the loop
    # loopy schloopy
    ids = []
    found = [self.id]
    while !found.blank?
      ids.concat(found)
      found = ::Insurable.where(insurable_id: found).where.not(id: ids).order(:id).group(:id).pluck(:id)
    end
    ids = ids.shift if exclude_self
    # return everything
    return ::Insurable.where(id: ids)
  end

  def units_relation
    own_units = insurables.where(insurable_type_id: InsurableType::UNITS_IDS)
    buildings_units =
      Insurable.where(
        insurable_type_id: InsurableType::UNITS_IDS,
        insurable_id: insurables.where(insurable_type_id: InsurableType::BUILDINGS_IDS).pluck(:id)
      )

    own_units.or buildings_units
  end

  def buildings
    insurables.where(insurable_type_id: InsurableType::BUILDINGS_IDS)
  end

	def parent_community
    return self if InsurableType::COMMUNITIES_IDS.include?(self.insurable_type_id)
    return nil if self.insurable_id.nil?
    return self.insurable if InsurableType::COMMUNITIES_IDS.include?(self.insurable&.insurable_type_id)
    return self.insurable&.insurable if InsurableType::COMMUNITIES_IDS.include?(self.insurable&.insurable&.insurable_type_id)
    return nil
  end

  def parent_community_for_all
    parent_community
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
  
  def authorized_to_provide_for_address?(carrier_id, policy_type_id, agency: nil)
    addresses.each do |address|
      return true if authorized == true

      args = {
        carrier_id: carrier_id,
        policy_type_id: policy_type_id,
        state: address.state,
        zip_code: address.zip_code,
        plus_four: address.plus_four
      }
      authorized = (agency || self.agency || account.agency)&.offers_policy_type_in_region(args)
    end
    authorized
  end

  def unit?
    InsurableType::UNITS_IDS.include?(insurable_type_id)
  end

  def refresh_policy_type_ids(and_save: false)
    self.policy_type_ids = self.carrier_insurable_profiles.any?{|cip| cip.carrier_id == DepositChoiceService.carrier_id && cip.external_carrier_id } ? [DepositChoiceService.policy_type_id] : []
    
    
    # THIS IS TURNED OFF FOR NOW, IT'S GOTTEN INSANELY MORE COMPLICATED SO WE'RE RESTRICTING TO DEPOSIT CHOICE:
    #my_own_little_agency = (self.agency_id ? ::Agency.where(id: self.agency_id).take : nil) || self.account&.agency || nil
    #if my_own_little_agency.nil? || self.primary_address.nil?
    #  self.policy_type_ids = []
    #else
    #  self.policy_type_ids = CarrierAgencyAuthorization.where(carrier_agency: my_own_little_agency.carrier_agencies, state: self.primary_address&.state, available: true)
    #                                                   .order("policy_type_id").group("policy_type_id").pluck("policy_type_id")
    #  self.policy_type_ids &= self.insurable_type.policy_type_ids
    #end
    if and_save
      self.save
    end
  end

  def insurable_hierarchy(include_self: true)
    to_return = include_self ? [self] : []
    to_add = self
    while !(to_add = to_add.insurable).nil?
      to_return.push(to_add)
    end
    return to_return
  end

  # RETURNS EITHER:
  #   nil:                      no match was found and creation wasn't allowed
  #   an insurable:             a match was found or created
  #   an array of insurables:   multiple potential matches were found
  #   a hash:                   an error occurred; will have keys [:error_type, :message, :details], with :details optional
  def self.get_or_create(
    address: nil,                 # an address string (required unless unit title and insurable_id provided)
    county: nil,                  # an optional county string (will be used during creation, or applied to all countyless matching addresses)
    unit: nil,                    # true to search for units, false to search for buildings/communities, a string to search for a specific unit title; nil means search for a unit if address has line 2 and a community otherwise
    insurable_id: nil,            # optional; the community/building the sought insurable must belong to
    create_if_ambiguous: false,   # pass true to force insurable creation if there's any ambiguity (example: if you've already called this and got 'multiple' type results, none of which were what you wanted)
    disallow_creation: false,     # pass true to ONLY query, NOT create
    created_community_title: nil, # optionally pass the title for the community in case we have to create it (defaults to combined_street_address)
    account_id: nil,              # optionally, the account id to use if we create anything
    communities_only: false,      # if true, in unit mode does nothing; out of unit mode, searches only for communities with the address (no buildings)
    ignore_street_two: false,     # if true, will strip out street_two address data
    titleless: false,             # if true and unit is true, will seek a unit without a title
    neighborhood: nil,            # if provided, should be a string; this will populate Address#neighborhood if a single result is found & that field is empty
    diagnostics: nil              # pass a hash to get diagnostics; these will be the following fields, though applicable to code not encountered may be nil:
                                  #   address_used:               true if address used, false if we didn't need it
                                  #   title_derivation_tried:     true if we tried to derive a unit title from address line 2
                                  #   title_derivation_succeeded: true if we successfully got a title from address line 2
                                  #   title_as_derived:           string containing derived title, if there was one
                                  #   unit_mode:                  true if we searched for a unit, false if for a building/community
                                  #   IF UNIT_MODE:
                                  #     unit_count:               # of units found
                                  #     parent_count:             # of compatible parent communities/buildings found (before cull for non-ho4)
                                  #     parent_created:           true if we created a parent
                                  #     parent:                   the parent object itself
                                  #     target_created:           true if we created a unit
                                  #   IF NOT UNIT MODE:
                                  #     parent_count:             # of compatible parent communities found
                                  #     parent:                   the parent community of our found/created building (or, usually, nil)
                                  #     tried_street_two_match:   true if we had a non-nil street two which we tried to match
                                  #     street_two_match_count:   # of successful matches for street 2
                                  #     target_created:           true if we created a community/building
  )
    # validate params
    if address.blank? && !unit && !insurable_id.nil?
      return Insurable.where(id: insurable_id).take
    elsif address.blank? && ([true,false,nil].include?(unit) || insurable_id.nil?)
      raise ArgumentError.new(I18n.t('insurable_model.either_address_must_be_provided'))
    end
    county = nil if county.blank?
    # if we have a unit title and an insurable id, get or create the unit without dealing with address nonsense
    unit_title = [true,false,nil].include?(unit) ? nil : clean_unit_title(unit)
    unit_title = :titleless if titleless
    if !unit_title.blank? && !insurable_id.nil?
      if diagnostics
        diagnostics[:unit_mode] = true
        diagnostics[:address_used] = false
      end
      results = ::Insurable.where(title: unit_title == :titleless ? nil : unit_title, insurable_id: insurable_id, insurable_type_id: ::InsurableType::RESIDENTIAL_UNITS_IDS)
      case results.count
        when 0
          return nil if disallow_creation
          results = ::Insurable.where(id: insurable_id, insurable_type_id: ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS | ::InsurableType::RESIDENTIAL_BUILDINGS_IDS).take
          if results.blank?
            return { error_type: :invalid_community, message: "The requested residential building/community does not exist" }
          end
          community = (results.parent_community || results)
          community.primary_addres.update(neighborhood: neighborhood) if !neighborhood.blank? && community.primary_address.neighborhood.blank?
          unit = results.insurables.new(
            title: unit_title == :titleless ? nil : unit_title,
            insurable_type: ::InsurableType.where(title: "Residential Unit").take,
            enabled: true, category: 'property', preferred_ho4: false,
            account_id: account_id || nil
          )
          unless unit.save
            return { error_type: :invalid_unit, message: I18n.t('insurable_model.unable_create_unit'), details: unit.errors.full_messages }
          end
          return unit
        when 1
          return results.first
        else
          return results.to_a
      end
    end
    diagnostics[:address_used] = true if diagnostics
    # get a valid address model if possible
    if address.class == ::Address
      unless address.valid?
        return { error_type: :invalid_address, message: I18n.t('insurable_model.invalid_address'), details: address.errors.full_messages }
      end
    else
      address = ::Address.from_string(address)
      unless address.errors.blank?
        return { error_type: :invalid_address, message: I18n.t('insurable_model.invalid_address_value'), details: address.errors.full_messages }
      end
    end
    address.id = nil
    address.street_two = nil if ignore_street_two
    address.neighborhood = neighborhood
    # set county if provided
    unless county.blank?
      address.county = county
    end
    # try to figure out unit title if applicable
    seeking_unit = unit ? true : unit.nil? ? !address.street_two.blank? : false
    diagnostics[:unit_mode] = seeking_unit if diagnostics
    if seeking_unit
      if unit_title.blank? && !address.street_two.blank?
        diagnostics[:title_derivation_tried] = true if diagnostics
        cleaned = clean_unit_title(address.street_two)
        unless cleaned.nil?
          unit_title = cleaned
          if diagnostics
            diagnostics[:title_derivation_succeeded] = true
            diagnostics[:title_as_derived] = unit_title
          end
        end
      end
    end
    # search for the insurable
    if seeking_unit # we want a unit
      communities_only = false # WARNING: we just hack this to false here to prevent weird behavior, remove hack to make the default for this "ignore buildings and consider only community-attached units"
      if unit_title.nil?
        return { error_type: :invalid_address_line_two, message: I18n.t('insurable_model.unable_deduce_unit'), details: "'#{address.street_two}' #{I18n.t('insurable_model.not_standart_format')}" }
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
          insurable_type_id: ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS | (communities_only ? [] : (::InsurableType::RESIDENTIAL_BUILDINGS_IDS | ::InsurableType::RESIDENTIAL_UNITS_IDS))
        }
      ).order(:id).group(:id).pluck(:id)
      results = nil
      if !insurable_id.nil?
        parent_ids = parent_ids & [insurable_id]
        results = ::Insurable.where({
          title: unit_title == :titleless ? nil : unit_title,
          insurable_type_id: ::InsurableType::RESIDENTIAL_UNITS_IDS,
          insurable_id: parent_ids
        })
      else
        results = ::Insurable.where({
          title: unit_title == :titleless ? nil : unit_title,
          insurable_type_id: ::InsurableType::RESIDENTIAL_UNITS_IDS,
          insurable_id: parent_ids
        }).or(::Insurable.where({ # gotta account for the possibility that a standalone-addressed unit came up in our initial query
          id: parent_ids,
          title: unit_title == :titleless ? nil : unit_title,
          insurable_type_id: ::InsurableType::RESIDENTIAL_UNITS_IDS
        }))
      end
      # handle the units returned by the query
      diagnostics[:unit_count] = results.count if diagnostics
      results.map{|wst| wst.primary_address }.select{|a| a && a.neighborhood.blank? }.each{|a| a.update(neighborhood: neighborhood) } unless neighborhood.blank?
      case results.count
        when 0
          # unit does not exist; find a parent we can create on
          return nil if disallow_creation
          parents = ::Insurable.where(id: parent_ids, insurable_type_id: ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS | (communities_only ? [] : ::InsurableType::RESIDENTIAL_BUILDINGS_IDS))
          parent = parents.sort{|a,b| (::InsurableType::RESIDENTIAL_BUILDINGS_IDS.include?(a) ? -1 : 1) <=> (::InsurableType::RESIDENTIAL_BUILDINGS_IDS.include?(b) ? -1 : 1) }.first
          diagnostics[:parent_count] = parents.count if diagnostics
          if parent.nil?
            # flee if prevented from creating community
            if disallow_creation
              return nil
            elsif !insurable_id.nil?
              return { error_type: :invalid_community, message: I18n.t('insurable_model.request_residential_build_not_exist') }
            elsif parents.count > 0 # this no longer happens, but if we ever forbid creating on preferred communities/buildings again, the "parent =" line above should be changed so that this will execute
              return { error_type: :invalid_unit, message:  I18n.t('insurable_model.unit_doesnot_exist') }
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
              account_id: account_id || nil
            )
            unless parent.save
             return { error_type: :invalid_community, message: I18n.t('insurable_model.unable_create_community_from_address'), details: parent.errors.full_messages }
            end
            if diagnostics
              diagnostics[:parent_created] = true
              diagnostics[:parent] = parent
            end
          end
          # create the unit
          unit = parent.insurables.new(
            title: unit_title == :titleless ? nil : unit_title,
            insurable_type: ::InsurableType.where(title: "Residential Unit").take,
            enabled: true, category: 'property', preferred_ho4: false,
            account_id: account_id || nil
          )
          unless unit.save
            return { error_type: :invalid_unit, message: I18n.t('insurable_model.unable_create_unit'), details: unit.errors.full_messages }
          end
          diagnostics[:target_created] = true if diagnostics
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
          insurable_type_id: ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS | (communities_only ? [] : ::InsurableType::RESIDENTIAL_BUILDINGS_IDS),
          insurable_id: insurable_id,
          title: created_community_title
        }.compact
      )
      if county # set counties on results if missing but provided (result primary addresses all have the same postal address up to line 2 hence the same county)
        Address.where(id: results.map{|r| r.primary_address.county.blank? ? r.primary_address.id : nil }.compact).update_all(county: county)
      end
      diagnostics[:parent_count] = results.count if diagnostics
      unless address.street_two.blank?
        with_street_two = results.select{|res| res.primary_address.street_two&.strip == address.street_two.strip }
        if diagnostics
          diagnostics[:tried_street_two_match] = true
          diagnostics[:street_two_match_count] = with_street_two.count
        end
        with_street_two.map{|wst| wst.primary_address }.select{|a| a && a.neighborhood.blank? }.each{|a| a.update(neighborhood: neighborhood) } unless neighborhood.blank?
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
      results.map{|wst| wst.primary_address }.select{|a| a && a.neighborhood.blank? }.each{|a| a.update(neighborhood: neighborhood) } unless neighborhood.blank?
      case results.count
        when 0
          return nil if disallow_creation
          # try to get parent if applicable
          parent = nil
          unless insurable_id.nil?
            parent = ::Insurable.where(id: insurable_id, insurable_type_id: ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS).take
            if parent.nil?
              return { error_type: :invalid_building, message: I18n.t('insurable_model.parent_community_not_exist') }
            else
              parent_address = parent&.primary_address
              if parent_address.state != address.state || parent_address.zip_code != address.zip_code || parent_address.city != address.city
                return { error_type: :invalid_building, message: I18n.t('insurable_model.parent_community_not_the_same') }
              end
            end
          end
          diagnostics[:parent] = parent if diagnostics
          # create community (or building, if there was a parent provided)
          address.id = nil
          address.primary = true
          created = ::Insurable.new(
              title: created_community_title || address.combined_street_address,
              insurable_type: ::InsurableType.where(title: parent.nil? ? "Residential Community" : "Residential Building").take,
              enabled: true, preferred_ho4: false, category: 'property',
              addresses: [ address ],
              account_id: account_id || nil
            )
          created.insurable_id = parent.id if parent
          unless created.save
            message = parent.nil? ? I18n.t('insurable_model.unable_to_create_from_address') : I18n.t('insurable_model.unable_to_create_building_from_address')
           return { error_type: :"invalid_#{parent.nil? ? 'community' : 'building'}",
                    message: message,
                    details: created.errors.full_messages }
          end
          diagnostics[:target_created] = true if diagnostics
          return created
        when 1
          return results.first
        else
          return results.to_a
      end
    end
    # every possible case resulted in a return already
    return { error_type: :internal_error, message: I18n.t('insurable_model.internal_error_occured') }
  end

  def refresh_insurable_data
    # Todo: Remove before 2023-02-01, left in place to make sure no errors would pop up
    # InsurablesData::Refresh.run!(insurable: self)
    nil
  end
  
  def get_qbe_traits(
    force_defaults: false,  # pass true here to force defaults even if the property's state does not support QBE defaults for final bind
    extra_settings: nil,    # pass policy_application.extra_settings if you have any
    # you can optionally pass these to avoid unnecessary queries, for efficiency:
    community: nil, community_profile: nil, community_address: nil
  )
    community ||= self.parent_community
    community_profile ||= community.carrier_profile(QbeService.carrier_id)
    to_return = if !community.account_id.nil? && !community_profile.nil? && community_profile.traits["pref_facility"] != "FIC" # MOOSE WARNING: ideally even if it's FIC, if we have the data we should use the data... but if we have it, we should be able to use it as MDU, so this is fine for now
      {
        city_limit: community_profile.traits['city_limit'] == true ? 1 : 0,
        units_on_site: community.units.confirmed.count,
        age_of_facility: community_profile.traits['construction_year'],
        gated_community: community_profile.traits['gated'] == true ? 1 : 0,
        prof_managed: community_profile.traits['professionally_managed'] == true ? 1 : 0,
        prof_managed_year: (community_profile.traits['professionally_managed'] == true && !community_profile.traits['professionally_managed_year'].blank?) ? community_profile.traits['professionally_managed_year'] : ""
      }
    else
      # we leave these guys nil if they are not provided here or via defaults
      community_address ||= community.primary_address
      defaults = ::QbeService::FIC_DEFAULTS[community_address.state] || ::QbeService::FIC_DEFAULTS[nil]
      pmy = (extra_settings&.[]('years_professionally_managed') ? extra_settings&.[]('years_professionally_managed').to_i.abs : defaults&.[]('years_professionally_managed'))
      {
        city_limit: { true => 1, false => 0, nil => nil }[extra_settings&.has_key?('in_city_limits') ? extra_settings['in_city_limits'] : defaults&.[]('in_city_limits')],
        units_on_site: extra_settings&.[]('number_of_units') || defaults&.[]('number_of_units'),
        age_of_facility: extra_settings&.[]('year_built') || defaults&.[]('year_built'),
        gated_community: { true => 1, false => 0, nil => nil }[extra_settings&.has_key?('gated') ? extra_settings['gated'] : defaults&.[]('gated')],
        prof_managed: pmy.nil? ? nil : pmy == 0 ? 0 : 1,
        prof_managed_year: pmy.nil? ? nil : pmy == 0 ? "" : (Time.current.to_date.year - pmy).to_s
      }
    end
    if force_defaults
      to_return[:city_limit] = false if to_return[:city_limit].nil?
      to_return[:units_on_site] ||= 40
      to_return[:age_of_facility] ||= 1996
      to_return[:prof_managed] = 0 if to_return[:prof_managed].nil?
      to_return[:prof_managed_year] = 0 if to_return[:prof_managed_year].nil?
    end
    return to_return
  end

  def slug_url
    "/#{self.insurable_type.title.split(' ')[0].downcase}/#{self.slug}-#{self.id}"
  end

  def coverage_requirements_by_date(date: DateTime.current.to_date)
    return self.coverage_requirements.where("start_date < ?", date).order("start_date desc").limit(1).take
  end

  private

  def flush_parent_insurable_id
    if Rails.env == "production"
      self.insurable_id = nil
    else
      raise ArgumentError.new(
        "#{ self.title } IS A COMMUNITY!  NO PARENT INSURABLE FOR A COMMUNITY!  NO MORE INFINITE RECURSION!"
      ) unless self.insurable_id.nil?
    end
  end

  # NOTE: Commented out according to GCVR2-768: Master Policy Fixes
  # NOTE: Master Policy Assignment moved MasterCoverageSweepJob
  # NOTE: Recovered
  def assign_master_policy
    return if InsurableType::COMMUNITIES_IDS.include?(insurable_type_id) || insurable.blank?

    master_policy = insurable.policies.current.where(policy_type_id: PolicyType::MASTER_IDS).take
    if master_policy.present? && insurable.policy_insurables.where(policy: master_policy).take.auto_assign
      if InsurableType::BUILDINGS_IDS.include?(insurable_type_id) && master_policy.insurables.find_by(id: id).blank?
        PolicyInsurable.create(policy: master_policy, insurable: self, auto_assign: true)
      end
      Insurables::MasterPolicyAutoAssignJob.perform_later # try to cover if its possible
    end
  end

    def title_uniqueness
      return if insurable.nil?
      if insurable.insurables.where(title: title, insurable_type: insurable_type).any?
        errors.add(:title, I18n.t('insurable_model.should_be_uniq_inside_group'))
      end
    end

    def create_profile_by_carrier
      if insurable_type.title.include? "Residential"
        carrier_profile(1)
      else
        carrier_profile(3)
      end
    end

    def self.clean_unit_title(unit_title)
      splat = unit_title.gsub('#', ' ').gsub('.', ' ')
                        .gsub(/\s+/m, ' ').gsub(/^\s+|\s+$/m, '')
                        .split(" ").select do |strang|
                          ![
                            # english
                            'apartment', 'apt', 'ap', 'unit',
                            'fl', 'flt', 'flat', 'rm', 'room',
                            'no', 'num', 'number', 'ste', 'suite',
                            'ofc', 'office',
                            # spanish (also no and num from above)
                            'apartamento', 'apto', 'unidad',
                            'piso', 'lanta', 'numero', 'oficina',
                            'pta'
                          ].include?(strang.downcase)
                        end
      return(splat.size == 1 ? splat[0] : nil)
    end
    
    def set_confirmed_automatically
      self.confirmed = !self.account_id.nil?
    end
end
