class AddPayerToPaymentProfile < ActiveRecord::Migration[5.2]
  def up
    add_column :staffs, :stripe_id, :string
    add_column :staffs, :current_payment_method, :integer
    
    add_reference :payment_profiles, :payer, polymorphic: true, index: true
    PaymentProfile.find_each do |profile|
      profile.payer_id = profile.user_id
      profile.payer_type = 'User'
      profile.save
    end
    remove_reference :payment_profiles, :user, index: true
  end
  
  def down
    remove_column :staffs, :stripe_id, :string
    remove_column :staffs, :current_payment_method, :integer

    add_reference :payment_profiles, :user, index: true
    PaymentProfile.find_each do |profile|
      profile.user_id = profile.payer_id if profile.payer_type == 'User'
      profile.save
    end
    remove_reference :payment_profiles, :payer, polymorphic: true, index: true
  end
end
