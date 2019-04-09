# frozen_string_literal: true

class Staff < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  include DeviseTokenAuth::Concerns::User

  # Active Record Callbacks
  after_initialize :initialize_staff
  
  # belongs_to relationships
  belongs_to :organizable, 
    polymorphic: true,
    required: false
  
  # has_many relationships
      
  # has_one relationships
  has_one :profile,
  		as: :profileable,
  		autosave: true
  		
  	accepts_nested_attributes_for :profile
  	
  	private
  		
  		def initialize_staff
	  		# Blank for now...
	  	end
end
