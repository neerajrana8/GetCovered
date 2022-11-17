# frozen_string_literal: true

class RestoreMissingMailingAddress < ActiveRecord::Migration[6.1]
  def up
    policies = Policy.where(policy_in_system: false, address: nil)
    policies.each do |p|
      address_string = p.policy_users.where(primary: true).first&.user&.address&.full
      p.update_columns(address: address_string)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
