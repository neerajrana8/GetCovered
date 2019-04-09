# SetAccountUser Concern
# file: app/models/concerns/set_account_user.rb

module SetAccountUser
  extend ActiveSupport::Concern

  included do
    after_save :set_account_user,
      unless: Proc.new { |obj| obj.user.nil? }
  end

  def set_account_user
    
    account = respond_to?(:account) ? account : lease.account
    target_user = self.user
    
    unless target_user.nil? || account.nil?
      if account.users.exists?(target_user.id)
        account_user = AccountUser.where(user_id: target_user.id, account_id: account.id).first
        account_user.update(status: 'enabled') if account_user.enabled? == false  
      else
        account.users << target_user
      end  
    end

  end
  
end
