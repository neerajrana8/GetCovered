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
  include EarningsReport, 
          # RecordChange, 
          SetCallSign, 
          SetSlug,
          StripeConnect
  
  # Active Record Callbacks
  after_initialize :initialize_agency
  
  # belongs_to relationships
  belongs_to :agency
  
  # has_many relationships
  has_many :staff,
  		as: :organizable
  		
  has_many :branding_profiles,
    as: :profileable
	
	has_many :insurables
	
	has_many :events,
	    as: :eventable
	
	has_many :addresses,
       as: :addressable,
       autosave: true

  accepts_nested_attributes_for :addresses

  has_many :histories,
    as: :recordable

  validates_presence_of :title
  
  def owner
	  return staff.where(id: staff_id).take
	end
  
  def primary_address
		return addresses.where(primary: true).take 
	end
  	
	private
		
		def initialize_agency
  		# Blank for now...
  	end
end
