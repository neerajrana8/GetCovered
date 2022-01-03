# Account User Model
# file: app/models/account_user.rb

class AccountUser < ApplicationRecord
  
  belongs_to :account
  belongs_to :user

  # Validations
  validates_presence_of :status
  validates_uniqueness_of :account_id, scope: "user_id", message: "is already associated with that user"

  enum status: ['pending', 'enabled', 'disabled']
end
