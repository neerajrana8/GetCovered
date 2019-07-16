# Account model
# file: app/models/account.rb
#
# An account is an entity which owns or lists property and entity's either in need
# of coverage or to track existing coverage.  Accounts are controlled by staff who 
# have been assigned the Account in their organizable relationship.

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
	
	has_many :addresses,
       as: :addressable,
       autosave: true

  accepts_nested_attributes_for :addresses

  validates_presence_of :title
  	
  	private
  		
  		def initialize_agency
	  		# Blank for now...
	  	end
end
