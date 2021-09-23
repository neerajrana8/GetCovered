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
  belongs_to :staff, optional: true # the owner
  
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

  scope :enabled, -> { where(enabled: true) }

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
    AttachPaymentSource.run(account: self, token: token, make_default: make_default)
  end

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :title, type: :text, analyzer: 'english'
      indexes :call_sign, type: :text, analyzer: 'english'
    end
  end
  
  
  # Get Msi General Party Info
  #
  # Get GeneralPartyInfo block for use in MSI requests
  def get_msi_general_party_info
    pseudoname = get_pseudoname
    gotten_email = self.contact_info&.[]("contact_email") 
    gotten_email = self.owner&.email || nil if gotten_email.blank?
    addr = primary_address.nil? ? nil : primary_address.full[0...50]
    {
      NameInfo: {
        PersonName: {
          GivenName: pseudoname.first,
          Surname:   pseudoname.last
        }.merge(addr.nil? ? {} : { OtherGivenName: addr })
      },
      Communications: { # feel free to add phone number here just like we do for user#get_msi_general_party_info
        EmailInfo: {
          EmailAddr: gotten_email
        }
      }
    }
  end
  
  def get_confie_general_party_info
    gotten_email = self.contact_info&.[]("contact_email") 
    gotten_email = self.owner&.email || nil if gotten_email.blank?
    {
      NameInfo: {
        CommlName: {
          CommercialName: self.title.strip,
          SupplementarynameInfo: {
            SupplementaryNameCd: "DBA",
            SupplementaryName: self.title.strip
          }
        }.compact
      },
      Communications: { # feel free to add phone number here just like we do for user#get_confie_general_party_info
        EmailInfo: {
          EmailAddr: gotten_email
        }
      }
    }
  end
  
  private
    
    def initialize_agency
      # Blank for now...
    end

    # get an array [first, last] presenting self.title as if it were a name;
    # guarantees nonempty first and last with length at most 50 characters;
    # will separate along space boundaries with the first name as short as possible when it can
    def get_pseudoname
    pseudoname = ['','']
    the_title = self.title.strip
    space_index = the_title.index(' ')
    if space_index.nil? || space_index > 50
      # there are no usable spaces
      if the_title.length > 50
        pseudoname[0] = the_title[0...50]
        pseudoname[1] = the_title[50...100]
      elsif the_title.length <= 1
        pseudoname[0] = the_title.blank? ? "NOT APPLICABLE" : the_title
        pseudoname[1] = "NOT APPLICABLE"
      else
        pseudoname[0] = the_title[0..(the_title.length/2)]
        pseudoname[1] = the_title[((the_title.length/2)+1)..-1]
      end
    else
      pseudoname[0] = the_title[0..space_index] # include the space for now
      pseudoname[1] = the_title[(space_index+1)..-1]
      # move words from last name to first name as long as we need to and can
      while pseudoname.last.length > 50
        space_index = pseudoname.last.index(' ')
        if space_index.nil? || pseudoname.first.length + space_index + 1 >= 51
          # we don't have a space index we can slice at
          break
        else
          # we have a space index we can slice at
          pseudoname[0] += pseudoname.last[0..space_index]
          pseudoname[1] = pseudoname.last[(space_index+1)...-1]
        end
      end
      # give up on spaces if we have to do so to fit it all
      if pseudoname.last.length > 50 && pseudoname.first.length < 50
        space_index = [pseudoname.last.length - 50, 50 - pseudoname.first.length].min # how many characters we can move
        pseudoname[0] += pseudoname.last[0...space_index]
        pseudoname[1] = pseudoname.last[space_index..-1]
      end
      # throw away anything excessive
      pseudoname[0].chomp!(' ')
      pseudoname[1] = pseudoname.last[0...50]
    end
    pseudoname[0].strip!
    pseudoname[1].strip!
    return pseudoname
  end
end
