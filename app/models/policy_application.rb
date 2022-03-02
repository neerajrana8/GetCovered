##
# =Policy Application Model
# file: +app/models/policy_application.rb+

class PolicyApplication < ApplicationRecord

  # Concerns
  include CarrierPensioPolicyApplication
  include CarrierCrumPolicyApplication
  include CarrierQbePolicyApplication
  include CarrierMsiPolicyApplication
  include CarrierDcPolicyApplication

  # Active Record Callbacks
  after_initialize :initialize_policy_application

  before_validation :set_reference, if: proc { |app| app.reference.nil? }
  before_validation :set_extra_settings_address

  after_create :set_up_application_answers

  belongs_to :carrier
  belongs_to :policy_type
  belongs_to :agency
  belongs_to :account, optional: true
  belongs_to :billing_strategy
  belongs_to :branding_profile, optional: true
  belongs_to :policy, optional: true
  belongs_to :policy_application_group, optional: true

  has_many :addresses, as: :addressable, autosave: true

  has_many :policy_insurables
  has_many :insurables, through: :policy_insurables, before_add: :check_address
  has_many :model_errors, as: :model, dependent: :destroy

  has_many :policy_users
  has_many :users, through: :policy_users

  has_many :events, as: :eventable

  has_one :primary_policy_user, -> { where(primary: true).take },
    class_name: 'PolicyUser'
  has_one :primary_user,
    class_name: 'User',
    through: :primary_policy_user,
    source: :user

  has_many :policy_quotes
  has_many :policy_premiums,
    through: :policy_quotes

  has_many :policy_rates
  has_many :insurable_rates,
    through: :policy_rates, before_add: :check_if_active

  has_many :policy_application_answers
  has_many :policy_application_fields,
    through: :policy_application_answers

  has_many :policy_coverages, autosave: true
  
  def carrier_agency; @crag ||= ::CarrierAgency.where(carrier_id: self.carrier_id, agency_id: self.agency_id).take; end

  accepts_nested_attributes_for :policy_users, :policy_rates, :policy_insurables

  validate :billing_strategy_agency_and_carrier_correct
  validate :billing_strategy_must_be_enabled
  validate :carrier_agency_valid
  validate :check_residential_question_responses,
    if: proc { |pol| pol.policy_type.title == "Residential" }
  validate :check_commercial_question_responses,
    if: proc { |pol| pol.policy_type.title == "Commercial" }
  validates_presence_of :expiration_date, :effective_date
  validate :date_order,
    unless: proc { |pol| pol.effective_date.nil? || pol.expiration_date.nil? }
  validate :user_age

  enum status: { started: 0, in_progress: 1, complete: 2, abandoned: 3,
                 quote_in_progress: 4, quote_failed: 5, quoted: 6,
                 more_required: 7, accepted: 8, rejected: 9 }

  def effective_moment
    self.effective_date&.beginning_of_day
  end
  
  def expiration_moment
    self.expiration_date&.end_of_day
  end

  # get carrier_agency_authorization
  def carrier_agency_authorization
    state = self.primary_insurable&.primary_address&.state
    ::CarrierAgencyAuthorization.references(:carrier_agencies).includes(:carrier_agency).where({
      state: state,
      policy_type_id: self.policy_type_id,
      carrier_agencies: {
        carrier_id: self.carrier_id,
        agency_id: self.agency_id
      }
    }.compact).take
  end


  # get tags
  def tags
    ::Tag.where(id: self.tag_ids)
  end

  # PolicyApplication.estimate()

  def estimate(args = [])
    method = "#{carrier.integration_designation}_estimate"
    complete? && respond_to?(method) ? send(*([method] + args)) : false
  end

  # PolicyApplication.quote()
  # Calls quote method for applicable carrier & service
  # using the naming convention #{ carrier.integration_designation }_quote
  # if the method exists.

  def quote(*args)
    self.reload
    method = "#{carrier.integration_designation}_quote"
    respond_to?(method) ? send(*([method] + args)) : false
  end

  # PolicyApplication.primary_insurable

  def primary_insurable
    policy_insurable = policy_insurables.find{|pi| pi.primary }&.insurable
  end

  # PolicyApplication.primary_insurable

  def primary_user
    return policy_users.find{|pi| pi.primary }&.user
  end

  # PolicyApplication.available_rates

  def available_rates(opts = {})
    query = {
      number_insured: users.count,
      interval: 'month'
    }.merge!(opts)
    primary_insurable.insurable_rates
      .count > 0 ? primary_insurable.insurable_rates.where(query) :
                                           primary_insurable.insurable.insurable_rates.where(query)
  end

  def check_address(insurable)
    throw :no_address if insurable.primary_address.nil?
  end

  def check_if_active(insurable_rate)
    throw :must_be_active if insurable_rate.activated != true
  end

  def billing_strategy_agency_and_carrier_correct
		errors.add(:billing_strategy, I18n.t('policy_app_model.billing_strategy_must_belong')) if agency != billing_strategy.agency
    errors.add(:billing_strategy, I18n.t('policy_app_model.billing_strategy_must_be_valid')) unless billing_strategy.carrier_id == self.carrier_id
  end

  def billing_strategy_must_be_enabled
    errors.add(:billing_strategy, I18n.t('policy_app_model.billing_strategy_must_be_enabled')) unless billing_strategy.enabled == true
  end

  def carrier_agency_valid
    errors.add(:carrier, I18n.t('policy_app_model.carrier_agency_must_exist')) unless agency.carriers.include?(carrier)
    # ensure auth
    addr = self.primary_insurable&.primary_address
    unless addr.nil? # skip validation if there is no address, so that PENSIO hack and potential future addressless insurables don't fail
      auths = CarrierAgencyAuthorization.references(:carrier_agencies).includes(:carrier_agency)
                                        .where(
                                          carrier_agencies: { carrier_id: self.carrier_id, agency_id: self.agency_id },
                                          policy_type_id: self.policy_type_id,
                                          state: addr.state,
                                          available: true
                                        ) # MOOSE WARNING: add zip_code_blacklist checks?
      errors.add(:policy_type, I18n.t('policy_app_model.is_not_available_for_this_carrier')) if auths.blank?
    end
  end

  def check_residential_question_responses
    if self.carrier_id == QbeService.carrier_id
      liability_number = self.coverage_selections&.[]("liability")&.[]("selection")&.[]("value").to_i
      if liability_number == 30000000
        self.questions.select{|q| q['value'] == 'true' }.each do |question|
          errors.add(:questions, "#{ question["title"] } #{I18n.t('policy_app_model.cannot_be_true_with_liability_limit')}")
        end
      end
    end
	end

  def check_commercial_question_responses

		questions.each do |question|
			if question.has_key?("questions")
				question["questions"].each do |sub_question|
					question_text = "#{ question["text"] } #{ sub_question["text"] }"
					if sub_question["options"][0].is_a? Integer
						errors.add(:questions, "#{ question_text } #{I18n.t('policy_app_model.cannot_be_greater_than')}") if sub_question["value"] > 0
					else
						errors.add(:questions, "#{ question_text } #{I18n.t('policy_app_model.cannot_be_true')}") if sub_question["value"] == true
					end
				end
			else
  			errors.add(:questions, "#{ question["text"] } #{I18n.t('policy_app_model.cannot_be_true')}") if question["value"] == true
			end
		end

	end

  def build_from_carrier_policy_type
    unless carrier.nil? || policy_type.nil?
      carrier_policy_type = CarrierPolicyType.where(carrier: carrier, policy_type: policy_type).take
      unless carrier_policy_type.nil?
        self.fields = carrier_policy_type.application_fields
        self.questions = carrier_policy_type.application_questions
      end
    end
  end
  

  # call this to get an access token to allow accessing an existing application
  def create_access_token
    return AccessToken.create({
      expires_at: Time.current + 2.weeks,
      bearer: self.primary_user,
      access_type: 'application_access',
      access_data: {
        'policy_application_id' => self.id
      }
    })
  end

  private

    def initialize_policy_application; end

    def date_order
      errors.add(:expiration_date, I18n.t('policy_app_model.expiration_date_cannot_be_before_effective')) if expiration_date < effective_date
    end

    def set_reference
      return_status = false

      if reference.nil?
        loop do
          parent_entity = account.nil? ? agency : account
          self.reference = "#{parent_entity.call_sign}-#{rand(36**12).to_s(36).upcase}"
          return_status = true

          break unless PolicyApplication.exists?(reference: reference)
        end
      end

      return_status
    end

    def set_up_application_answers
      carrier.policy_application_fields
        .where(policy_type: policy_type, enabled: true)
        .each do |field|

        policy_application_answers.create!(
          policy_application_field: field
        )
      end
    end
  
    def set_extra_settings_address
      # this is because MSI expects 'address' and QBE expects a broken-down address into fieldy_boiz... this is a hack to let the client send up just fieldy boiz for now
      if self.extra_settings && self.extra_settings['additional_interest']
        fieldy_boiz = ['addr1', 'addr2', 'city', 'state', 'zip']
        unless (fieldy_boiz - ['addr2']).all?{|fb| self.extra_settings['additional_interest'][fb].blank? }
          self.extra_settings['additional_interest']['address'] = fieldy_boiz.map{|fb| self.extra_settings['additional_interest'][fb] }
                                                                             .map.with_index{|val, ind| (ind == 2 || ind == 4) && !val.blank? ? ", #{val}" : val }
                                                                             .select{|val| !val.blank? }
                                                                             .join(" ")
        end
      end
    end
    
    def user_age
      pu = self.primary_user
      errors.add(:policy_holder, I18n.t('policy_app_model.user_age', name: [pu.profile.first_name, pu.profile.last_name].join(" "))) unless pu.nil? || pu.profile.birth_date&.<=(18.years.ago)
    end
end
