# Account User Model
# file: app/models/account_user.rb

class AccountUser < ApplicationRecord
  
  belongs_to :account,
    required: true
  belongs_to :user,
    required: true

  validate :account_user_is_unique,
    unless: Proc.new { |au| au.account.nil? || au.user.nil? }

  enum status: ['pending', 'enabled', 'disabled']
  
  private
    
    def account_user_is_unique
      if AccountUser.where(user_id: user_id, account_id: account_id).count > 1
        errors.add(:user, "already belongs to account")  
      end
    end
    
end
