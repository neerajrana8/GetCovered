# Agency model
# file: app/models/agency.rb
#
# An agency is an entity capable of issuing insurance policies on behalf of an
# insurance Carrier.  The agency is managed by staff who have been assigned the 
# Agency in their organizable relationship.

class Agency < ApplicationRecord
	# Concerns
	include EarningsReport, 
					RecordChange, 
					SetCallSign, 
					SetSlug,
					StripeConnect

  # Active Record Callbacks
  after_initialize :initialize_agency
  
  # belongs_to relationships
  
  # has_many relationships
  has_many :accounts
  
  has_many :staff,
  		as: :organizable
  		
  	has_many :account_staff,
  		through: :accounts,
  		as: :organizable,
  		source: :staff,
  		class_name: 'Staff'
      
  # has_one relationships
  # blank for now...
  	
  	private
  		
  		def initialize_agency
	  		# Blank for now...
	  	end
end
