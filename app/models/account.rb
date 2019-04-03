# Account model
# file: app/models/account.rb
#
# An account is an entity which owns or lists property and entity's either in need
# of coverage or to track existing coverage.  Accounts are controlled by staff who 
# have been assigned the Account in their organizable relationship.

class Account < ApplicationRecord
  # Active Record Callbacks
  after_initialize :initialize_agency
  
  # belongs_to relationships
  belongs_to :agency
  
  # has_many relationships
  has_many :staff,
  		as: :organizable
      
  # has_one relationships
  # blank for now...
  	
  	private
  		
  		def initialize_agency
	  		# Blank for now...
	  	end
end
