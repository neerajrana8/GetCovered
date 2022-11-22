# frozen_string_literal: true

class RestoreMissingMailingAddressWithPrimaryInsurable < ActiveRecord::Migration[6.1]
  def up
    policies = Policy.where(policy_in_system: false).where("updated_at > '2022-11-15'")
    # DEBUG policies = Policy.where(policy_in_system: false, id: [9147]).limit(10)
    policies.each do |policy|
      insurable_address = policy.primary_insurable&.addresses&.first
      next if insurable_address.nil?
      next if policy.primary_user.nil?
      if policy.primary_user&.address.nil?
        new_address_user = insurable_address.dup
        new_address_user.addressable_type = 'User'
        new_address_user.addressable_id = policy.primary_user.id
        new_address_user.save!
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
