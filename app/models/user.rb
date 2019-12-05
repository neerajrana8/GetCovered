# User model
# file: app/models/user.rb
# frozen_string_literal: true
require 'digest'

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable,
         :trackable, :validatable, :invitable, validate_on_invite: true
  include RecordChange
  include DeviseTokenAuth::Concerns::User
  include ElasticsearchSearchable

  # Active Record Callbacks
  after_initialize :initialize_user
  after_create_commit :add_to_mailchimp

	has_many :invoices

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
          
  has_many :account_users
  has_many :claims, as: :claimant
  has_many :events, as: :eventable

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

  has_many :payment_profiles
  has_many :accounts,
    through: :active_account_users

  accepts_nested_attributes_for :profile


  enum current_payment_method: ['none', 'ach_unverified', 'ach_verified', 'card', 'other'],
    _prefix: true

  enum mailchimp_category: ['prospect', 'customer']

  # VALIDATIONS
  validates :email, uniqueness: true
  
  # Override payment_method attribute getters and setters to store data
  # as encrypted
#   def payment_methods=(methods)
#     super(EncryptionService.encrypt(methods))
#   end
#
#   def payment_methods
#     super.nil? ? super : EncryptionService.decrypt(super)
#   end


  # Set Stripe ID
  #
  # Assigns stripe customer id to end user

  def set_stripe_id(token = nil, _token_type = 'card', default = false)
    if stripe_id.nil? && valid?
      
      stripe_customer = Stripe::Customer.create(
        :email    => email,
        :metadata => {
          :first_name => profile.first_name,
          :last_name  => profile.last_name
        }
      )
      
      pp stripe_customer
      
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
    AttachPaymentSource.run!(user: self, token: token, make_default: make_default)
  end
  
  settings index: { number_of_shards: 1, limit: 10_000 } do
    mappings dynamic: 'false' do
      indexes :email, type: :string
    end
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

  private
  
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

  	def add_to_mailchimp
      unless Rails.application.credentials.mailchimp[:list_id][ENV["RAILS_ENV"].to_sym] == "nil"
        post_data = {
          email_address: email,
          status: "subscribed",
          tags: [],
          merge_fields: { }
        }

        post_data[:merge_fields][:FNAME] = profile.first_name unless profile.first_name.nil?
        post_data[:merge_fields][:LNAME] = profile.last_name unless profile.last_name.nil?
        post_data[:merge_fields][:PHONE] = profile.contact_phone unless profile.contact_phone.nil?
        post_data[:tags].push(self.mailchimp_category)

        data_center = Rails.application.credentials.mailchimp[:api_key].partition('-').last
        url = "https://#{ data_center }.api.mailchimp.com/3.0/lists/#{ Rails.application.credentials.mailchimp[:list_id][ENV["RAILS_ENV"].to_sym] }/members"

	      event = events.create(
	        verb: 'post',
	        format: 'json',
	        interface: 'REST',
	        process: 'mailchimp_add_subscriber',
	        endpoint: url,
	        request: post_data,
	        started: Time.now
	      )

        request = HTTParty.post(url,
											 				  headers: {
											 				    "Authorization" => "apikey #{ Rails.application.credentials.mailchimp[:api_key] }",
											 				    "Content-Type" => "application/json"
                       				  },
                        				body: post_data.to_json)

        if request.has_key?("unique_email_id")
          self.update mailchimp_id: request["unique_email_id"]
          event.update response: request.to_json, status: 'success', completed: Time.now
        else
          event.update response: request.to_json, status: 'error', completed: Time.now
        end
      end
    end
end
