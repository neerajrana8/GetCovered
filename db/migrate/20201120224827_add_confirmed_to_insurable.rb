class AddConfirmedToInsurable < ActiveRecord::Migration[5.2]
  def up
    add_column :insurables, :confirmed, :boolean, null: false, default: true
    # get rid of nonpreferred residential
    nprid = ::Account.where(slug: 'nonpreferred-residential').take&.id
    unless nprid.blank?
      account_bearing_models = [::Lease, ::PolicyApplication, ::PolicyGroup, ::Policy, ::PolicyApplicationGroup, ::Insurable, ::AccountUser, ::PolicyGroupQuote, ::PolicyQuote]
      account_bearing_models.each do |model|
        model.where(account_id: nprid).update_all(account_id: nil)
      end
      Account.where(id: nprid).delete_all
    end
    # mark insurables confirmed if they have an account
    Insurable.where.not(account_id: nil).update_all(confirmed: true)
  end
  
  def down
    remove_column :insurables, :confirmed
    # add back nonpreferred residential
    nprid = ::Account.where(slug: 'nonpreferred-residential').take&.id
    if nprid.blank?
      ::Account.create(
        title: "Nonpreferred Residential",
        slug: "nonpreferred-residential",
        enabled: true, 
        whitelabel: true, 
        tos_accepted: true, 
        tos_accepted_at: Time.current, 
        tos_acceptance_ip: Socket.ip_address_list.select{ |intf| intf.ipv4_loopback? }, 
        verified: true, 
        stripe_id: nil,
        contact_info: {"contact_email"=>"nonpreferredresidential@getcoveredinsurance.com"}
      )
      nprid = ::Account.where(slug: 'nonpreferred-residential').take&.id
    end
    account_bearing_models = [::Lease, ::PolicyApplication, ::PolicyGroup, ::Policy, ::PolicyApplicationGroup, ::Insurable, ::AccountUser, ::PolicyGroupQuote, ::PolicyQuote]
    account_bearing_models.each do |model|
      model.where(account_id: nil).update_all(account_id: nprid)
    end
  end
end
