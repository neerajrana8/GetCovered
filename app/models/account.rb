# Account model
# file: app/models/account.rb
#
# An account is an entity which owns or lists property and entity's either in need
# of coverage or to track existing coverage.  Accounts are controlled by staff who 
# have been assigned the Account in their organizable relationship.
# export PUBLISHABLE_KEY="pk_test_EfYPHgUKyZYzJjWegJmBr2DR"
# export SECRET_KEY="sk_test_IBSW1QDuu306wJQCUQkattsa"

class Account < ApplicationRecord
  # Concerns
  include ElasticsearchSearchable
  include SetSlug
  include SetCallSign
  include EarningsReport
  include CoverageReport
  include RecordChange

  # Active Record Callbacks
  after_initialize :initialize_agency
  
  # belongs_to relationships
  belongs_to :agency
  
  # has_many relationships
  has_many :staff,
    as: :organizable

  # ActiveSupport +pluralize+ method doesn't work correctly for this word(returns staffs). So I added alias for it
  alias staffs staff
      
  has_many :branding_profiles, as: :profileable
  has_many :payment_profiles, as: :payer
  
  has_many :insurables 
  
  has_many :policies
  has_many :claims, through: :policies
  has_many :invoices, through: :policies
  has_many :payments, through: :invoices

  has_many :policy_applications
  has_many :policy_quotes

  has_many :leases
  
  has_many :account_users
  
  has_many :users,
    through: :account_users
  
  has_many :active_account_users,
    -> { where status: 'enabled' }, 
    class_name: 'AccountUser'
  
  has_many :active_users,
    through: :active_account_users,
    source: :user
  
  has_many :commission_strategies, as: :commissionable
  
  has_many :commissions, as: :commissionable
  has_many :commission_deductions, as: :deductee

  has_many :events,
    as: :eventable
  
  has_many :addresses,
    as: :addressable,
    autosave: true

  has_many :histories,
    as: :recordable

  has_many :reports,
    as: :reportable

  accepts_nested_attributes_for :addresses, allow_destroy: true

  # Validations

  validates_presence_of :title, :slug, :call_sign
  
  def owner
    staff.where(id: staff_id).take
  end
  
  def primary_address
    addresses.where(primary: true).take 
  end
  
  # Override as_json to always include agency and addresses information
  def as_json(options = {})
    json = super(options.reverse_merge(include: %i[agency primary_address owner]))
    json
  end

  def commission_balance
    commission_deductions.map(&:unearned_balance).reduce(:+) || 0
  end


  # Attach Payment Source
  #
  # Attach a stripe source token to a user (Stripe Customer)
  
  def attach_payment_source(token = nil, make_default = true)
    AttachPaymentSource.run!(account: self, token: token, make_default: make_default)
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
