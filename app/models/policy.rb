##
# =Policy Model
# file: +app/models/policy.rb+

class Policy < ApplicationRecord
  
  # Concerns
  include CarrierQbePolicy
  
  belongs_to :agency
  belongs_to :account
  belongs_to :carrier
  belongs_to :policy_type
  belongs_to :billing_profie
  
  has_many :policy_quotes
  has_one :policy_application
  
  has_many :policy_users
  has_many :users,
    through: :policy_users
    
  has_one :primary_policy_user, -> { where(primary: true).first }, 
    class_name: 'PolicyUser'
  has_one :primary_user,
    class_name: 'User',
    through: :primary_policy_user
  
  has_many :policy_coverages, autosave: true
  has_many :policy_premiums, autosave: true
  
  accepts_nested_attributes_for :policy_coverages, :policy_premiums
  
end
å