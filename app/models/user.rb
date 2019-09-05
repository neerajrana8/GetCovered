# frozen_string_literal: true

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable,
         :trackable, :validatable, :invitable, validate_on_invite: true
  include RecordChange
  include DeviseTokenAuth::Concerns::User
  include ElasticsearchSearchable

  # Active Record Callbacks
  after_initialize :initialize_user
	
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

  accepts_nested_attributes_for :profile


  enum current_payment_method: ['none', 'ach_unverified', 'ach_verified', 'card', 'other'], 
    _prefix: true

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

  def set_stripe_id(token = nil, token_type = 'card', default = false)
    if stripe_id.nil? && valid?
      
      stripe_customer = Stripe::Customer.create(
        :email    => email,
        :metadata => {
          :first_name => profile.first_name,
          :last_name  => profile.last_name
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
    begin
      # create the stripe customer if necessary
      customer = nil
      if self.stripe_id.nil?
        customer = Stripe::Customer.create(
          :email    => email,
          :metadata => {
            :first_name => profile.first_name,
            :last_name  => profile.last_name
          }
        )
        return false unless update_columns(stripe_id: customer.id)
      end
      unless token.nil?
        # common setup for both new and reused payment methods
        customer = Stripe::Customer.retrieve(stripe_id) if customer.nil?
        token_data = Stripe::Token.retrieve(token)
        stored_method = nil
        case token_data.type
          when 'bank_account'
            stored_method = self.payment_methods['fingerprint_index']['ach'].has_key?(token_data.bank_account.fingerprint) ?
              self.payment_methods['by_id'][self.payment_methods['fingerprint_index']['ach'][token_data.bank_account.fingerprint]] : nil
          when 'card'
            stored_method = self.payment_methods['fingerprint_index']['card'].has_key?(token_data.card.fingerprint) ?
              self.payment_methods['by_id'][self.payment_methods['fingerprint_index']['card'][token_data.card.fingerprint]] : nil
          else
            return false # flee in horror
        end
        # branch based on payment method's previous use
        if stored_method.nil? # payment method was not previously used
          case token_data.type
            when 'bank_account'
              customer.sources.create(source: token_data.id)
              customer.default_source = token_data.bank_account.id if make_default
              customer.save
              self.payment_methods['by_id'][token_data.bank_account.id] = {
                'type' => 'ach',
                'id' => token_data.bank_account.id,
                'fingerprint' => token_data.bank_account.fingerprint,
                'verified' => token_data.bank_account.status == 'verified' ? 'true' : 'false'
              }
              self.payment_methods['fingerprint_index']['ach'][token_data.bank_account.fingerprint] = token_data.bank_account.id
              if make_default
                self.current_payment_method = token_data.bank_account.status == 'verified' ? 'ach_verified' : 'ach_unverified'
                self.payment_methods['default'] = token_data.bank_account.id
              end
            when 'card'
              customer.sources.create(source: token_data.id)
              customer.default_source = token_data.card.id if make_default
              customer.save
              self.payment_methods['by_id'][token_data.card.id] = {
                'type' => 'card',
                'id' => token_data.card.id,
                'fingerprint' => token_data.card.fingerprint
              }
              self.payment_methods['fingerprint_index']['card'][token_data.card.fingerprint] = token_data.card.id
              if make_default
                self.current_payment_method = 'card'
                self.payment_methods['default'] = token_data.card.id
              end
          end
        else # payment method was previously used
          if make_default
            customer.default_source = stored_method['id']
            customer.save
            case token_data.type
              when 'bank_account'
                reactivated_bank_account = customer.sources.retrieve(stored_method['id'])
                self.payment_methods['by_id'][stored_method['id']]['verified'] = reactivated_bank_account.status == 'verified' ? true : false
                self.current_payment_method = (reactivated_bank_account.status == 'verified' ? 'ach_verified' : 'ach_unverified')
                self.payment_methods['default'] = stored_method['id']
              when 'card'
                self.current_payment_method = 'card'
                self.payment_methods['default'] = stored_method['id']
            end
          end
        end
        if self.save
          self.invoices.upcoming.each { |nvc| nvc.calculate_total(self.current_payment_method == 'card' ? 'card' : 'bank_account') } if make_default
          return true
        end
      end
    rescue Stripe::APIConnectionError => e
      errors.add(:payment_method, 'Network Error')
    rescue Stripe::StripeError => e
      errors.add(:payment_method, 'Unable to process account')
    end
    return false
  end
  
  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :email, type: :text
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
end
