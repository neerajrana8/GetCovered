# Lease User model
# file: app/models/lease_user.rb

class LeaseUser < ApplicationRecord
  
  # Callbacks
  before_create :set_first_as_primary
  after_create :set_account_user
  after_save :check_primary
  
  # Relationships
  belongs_to :lease
  belongs_to :user
    
  def related_records_list
    %w[lease user]  
  end
  
  private
    
  def set_first_as_primary
    # use this instead if you need to support manually setting false on the first one...
    #self.primary = true if lease.lease_users.find{|lu| lu != self }.nil? && primary.nil?
    self.primary = true unless lease.lease_users.exists?(primary: true)
  end
   
  def set_account_user
    acct = AccountUser.where(user_id: user.id, account_id: lease.account_id).take
    if acct.nil?
      AccountUser.create!(user: user, account: lease.account)
    elsif acct.status != 'enabled'
      acct.update(status: 'enabled')
    end
  end

  def check_primary
    if lease.lease_users.count > 1 && primary?

      lease.lease_users
        .where(primary: true)
        .where.not(id: id)
        .update(primary: false)
    end
  end
end
