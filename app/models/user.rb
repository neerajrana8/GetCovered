  # User model
# file: app/models/user.rb
# frozen_string_literal: true
require 'digest'

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable,
         :trackable, :invitable, validate_on_invite: true

  include RecordChange
  include DeviseCustomUser
  include SessionRecordable

  # Active Record Callbacks
  after_initialize :initialize_user
  
  before_validation :set_default_provider,
    on: :create
  
  before_validation :set_random_password,
    on: :create,
    if: Proc.new{|u| u.email.nil? && u.password.blank? }

  after_create_commit :add_to_mailchimp,
                      :set_qbe_id

	has_many :invoices, as: :payer

  has_many :authored_histories,
           as: :authorable,
           class_name: 'History',
           foreign_key: :authorable_id

  has_many :histories,
           as: :recordable,
           class_name: 'History',
           foreign_key: :recordable_id

  has_one :profile,
          as: :profileable,
          autosave: true

  has_one :address,
  				as: :addressable,
  				autosave: true

  has_one :lead

  has_many :account_users
  has_many :claims, as: :claimant
  has_many :events, as: :eventable

  has_many :integration_profiles,
           as: :profileable

  has_many :active_account_users,
    -> { where status: 'enabled' },
    class_name: "AccountUser"

  has_many :policy_users
  has_many :policies,
  	through: :policy_users
  has_many :policy_applications,
  	through: :policy_users
  has_many :policy_quotes,
    through: :policies
  has_many :lease_users
  has_many :leases,
    through: :lease_users

  has_many :payment_profiles, as: :payer
  has_many :accounts,
    through: :active_account_users

  has_many :agencies, through: :accounts
  has_many :notification_settings, as: :notifyable
  has_many :insurables, through: :policies

  accepts_nested_attributes_for :payment_profiles, :address
  accepts_nested_attributes_for :profile, update_only: true
  accepts_nested_attributes_for :address, update_only: true


  enum current_payment_method: ['none', 'ach_unverified', 'ach_verified', 'card', 'other'],
    _prefix: true

  enum mailchimp_category: ['prospect', 'customer']

  # VALIDATIONS
  validates_uniqueness_of :email, if: Proc.new{|u| u.email_changed? && !u.email.blank? }
  validates_format_of     :email, with: Devise.email_regexp, allow_blank: true, if: Proc.new{|u| u.email_changed? && !u.email.blank? }
  
  #validates_presence_of     :password
  validates_presence_of :password_confirmation, :if => Proc.new{|u| u.password_changed? && !u.password.blank? }
  validates_confirmation_of :password
  #validates_length_of       :password, within: Devise.password_length

  # Override payment_method attribute getters and setters to store data
  # as encrypted
  #   def payment_methods=(methods)
  #     super(EncryptionService.encrypt(methods))
  #   end
  #
  #    def payment_methods
  #     super.nil? ? super : EncryptionService.decrypt(super)
  #   end
  
  def self.create_with_random_password(*lins, **keys)
    u = ::User.new(*lins, **keys)
    u.send(:set_random_password)
    u.save
    return u
  end
  
  def self.create_with_random_password!(*lins, **keys)
    u = ::User.new(*lins, **keys)
    u.send(:set_random_password)
    u.save!
    return u
  end

  # Set Stripe ID
  #
  # Assigns stripe customer id to end user

  def set_stripe_id(token = nil, _token_type = 'card', default = false)
    if stripe_id.nil? && valid?

      stripe_customer = Stripe::Customer.create(
        email: email,
        metadata: {
          first_name: profile.first_name,
          last_name: profile.last_name,
          email: email,
          phone: profile&.contact_phone,
          agency: policies.take&.agency&.title,
          policy_number: policies.take&.number,
          product: policies.take&.policy_type&.title
        }
      )

      if update stripe_id: stripe_customer['id']
        return attach_payment_source(token, default) unless token.nil?

        return true
      else
        return false
      end
    else

      return false
    end
  end

  # Attach Payment Source
  #
  # Attach a stripe source token to a user (Stripe Customer)

  def attach_payment_source(token = nil, make_default = true)
    AttachPaymentSource.run(user: self, token: token, make_default: make_default)
  end

  def convert_prospect_to_customer
    if !mailchimp_id.nil? &&
       mailchimp_category == "prospect"

      data_center = Rails.application.credentials.mailchimp[:api_key].partition('-').last
      prospect_url = "https://#{ data_center }.api.mailchimp.com/3.0/lists/#{ Rails.application.credentials.mailchimp[:list_id][ENV["RAILS_ENV"].to_sym] }/segments/#{ Rails.application.credentials.mailchimp[:tags][:prospect][ENV["RAILS_ENV"].to_sym] }/members/#{ Digest::MD5.hexdigest self.email }"
      customer_url = "https://#{ data_center }.api.mailchimp.com/3.0/lists/#{ Rails.application.credentials.mailchimp[:list_id][ENV["RAILS_ENV"].to_sym] }/segments/#{ Rails.application.credentials.mailchimp[:tags][:customer][ENV["RAILS_ENV"].to_sym] }/members"
      customer_post_data = {
        "email_address": self.email
      }

      event = events.create(
        verb: 'post',
        format: 'json',
        interface: 'REST',
        process: 'mailchimp_remove_prospect_tag',
        endpoint: prospect_url,
        request: {}.to_json,
        started: Time.now
      )

      prospect_request = HTTParty.delete(prospect_url,
  										 				           headers: {
            										 				   "Authorization" => "apikey #{ Rails.application.credentials.mailchimp[:api_key] }",
            										 				   "Content-Type" => "application/json"
                                 				 })

      if prospect_request.code == 204
        event.update response: prospect_request.to_json, status: 'success', completed: Time.now

        customer_event = events.create(
          verb: 'post',
          format: 'json',
          interface: 'REST',
          process: 'mailchimp_add_customer_tag',
          endpoint: customer_url,
          request: customer_post_data.to_json,
          started: Time.now
        )

        customer_request = HTTParty.post(customer_url,
        											 				   headers: {
        											 				     "Authorization" => "apikey #{ Rails.application.credentials.mailchimp[:api_key] }",
        											 				     "Content-Type" => "application/json"
                               				   },
                                				 body: customer_post_data.to_json)

        if customer_request.code == 200
          customer_event.update response: customer_request.to_json, status: 'success', completed: Time.now
          self.update mailchimp_category: "customer"
        else
          customer_event.update response: customer_request.to_json, status: 'error', completed: Time.now
        end
      else
        event.update response: prospect_request.to_json, status: 'error', completed: Time.now
      end
    end
  end

  def hack_method(method=nil)
    if ["local", "development"].include?(ENV["RAILS_ENV"])
      self.send(method) unless method.nil?
    else
      return "ONLY WORKS IN LOCAL AND DEVELOPMENT ENVIRONMENTS"
    end
  end

  def get_msi_general_party_info
    {
      NameInfo: {
        PersonName: {
          GivenName: self.profile.first_name,
          Surname:   self.profile.last_name
        }.merge(self.profile.middle_name.blank? ? {} : { OtherGivenName: self.profile.middle_name })
      },
      Communications: {
        PhoneInfo: {
          PhoneNumber: (self.profile.contact_phone || '').tr('^0-9', '')
        },
        EmailInfo: {
          EmailAddr: self.email
        }
      }
    }
  end

  def get_confie_general_party_info(for_insurable: nil)
    {
      NameInfo: {
        PersonName: {
          GivenName:  self.profile.first_name,
          Surname:    self.profile.last_name
        }
      },
      Communications: {
        EmailInfo: {
          EmailAddr: self.email,
          DoNotContactInd: 0
        }
      }.merge(self.profile.contact_phone.blank? ? {} : {
        PhoneInfo: {
          PhoneNumber: (self.profile.contact_phone || '').tr('^0-9', ''),
          PhoneTypeCd: "Phone"
        }
      }),
      Addr: (
        for_insurable.blank? ? (self.address.blank? ? nil : self.address.get_confie_addr(true, address_type: "MailingAddress"))
        : for_insurable == true ? [
          self.address.nil? ? nil : self.address.get_confie_addr(true, address_type: "StreetAddress"),
          self.address.nil? ? nil : self.address.get_confie_addr(true, address_type: "MailingAddress")
        ].compact
        : [
          for_insurable.primary_address.get_confie_addr(::InsurableType::RESIDENTIAL_UNITS_IDS.include?(for_insurable.insurable_type_id) ? "Unit #{for_insurable.title}" : true, address_type: "StreetAddress"),
          self.address.blank? ?
            for_insurable.primary_address.get_confie_addr(::InsurableType::RESIDENTIAL_UNITS_IDS.include?(for_insurable.insurable_type_id) ? "Unit #{for_insurable.title}" : true, address_type: "MailingAddress")
            : self.address.get_confie_addr(true, address_type: "MailingAddress")
        ]
      )
    }.compact
  end

  def get_deposit_choice_occupant_hash(primary: false)
    {
      firstName:          self.profile.first_name,
      lastName:           self.profile.last_name,
      email:              self.email,
      principalPhone:     (self.profile.contact_phone || '').tr('^0-9', ''),
      isPrimaryOccupant:  primary
    }
  end

  private

  def history_blacklist
    %i[tokens]
  end

  def initialize_user
    self.current_payment_method ||= 'none'
    self.payment_methods ||= {
      'default' => nil,
      'by_id' => {},
      'fingerprint_index' => {
        'ach' => {},
        'card' => {}
      }
    }
    self.tokens ||= {}
  end

  def set_qbe_id

    return_status = false

    if qbe_id.nil?

      loop do
        self.qbe_id = Rails.application.credentials.qbe[:employee_id] + rand(36**7).to_s(36).upcase
        return_status = true

        break unless User.exists?(:qbe_id => self.qbe_id)
      end
    end

    update_column(:qbe_id, self.qbe_id) if return_status == true

    return return_status
  end
  
  def set_random_password
    secure_tmp_password = SecureRandom.base64(12)
    self.password = secure_tmp_password
    self.password_confirmation = secure_tmp_password
  end
  
  def set_default_provider
    self.provider = (self.email.blank? ? 'altuid' : 'email')
    self.altuid = Time.current.to_i.to_s + rand.to_s
    self.uid = self.altuid
  end

  	def add_to_mailchimp
#       unless Rails.application.credentials.mailchimp[:list_id][ENV["RAILS_ENV"].to_sym] == "nil"
#         post_data = {
#           email_address: email,
#           status: "subscribed",
#           tags: [],
#           merge_fields: { }
#         }
#
#         post_data[:merge_fields][:FNAME] = profile.first_name unless profile.first_name.nil?
#         post_data[:merge_fields][:LNAME] = profile.last_name unless profile.last_name.nil?
#         post_data[:merge_fields][:PHONE] = profile.contact_phone unless profile.contact_phone.nil?
#         post_data[:tags].push(self.mailchimp_category)
#
#         data_center = Rails.application.credentials.mailchimp[:api_key].partition('-').last
#         url = "https://#{ data_center }.api.mailchimp.com/3.0/lists/#{ Rails.application.credentials.mailchimp[:list_id][ENV["RAILS_ENV"].to_sym] }/members"
#
# 	      event = events.create(
# 	        verb: 'post',
# 	        format: 'json',
# 	        interface: 'REST',
# 	        process: 'mailchimp_add_subscriber',
# 	        endpoint: url,
# 	        request: post_data,
# 	        started: Time.now
# 	      )
#
#         request = HTTParty.post(url,
# 											 				  headers: {
# 											 				    "Authorization" => "apikey #{ Rails.application.credentials.mailchimp[:api_key] }",
# 											 				    "Content-Type" => "application/json"
#                        				  },
#                         				body: post_data.to_json)
#
#         if request.parsed_response.has_key?("unique_email_id")
#           self.update mailchimp_id: request.parsed_response["unique_email_id"]
#           event.update response: request.to_json, status: 'success', completed: Time.now
#         else
#           event.update response: request.to_json, status: 'error', completed: Time.now
#         end
#       end
    end
end
