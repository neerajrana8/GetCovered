# frozen_string_literal: true

class RestoreMissingMailingAddressWithPrimaryInsurable < ActiveRecord::Migration[6.1]
  def up
    policies = Policy.where(policy_in_system: false).where("updated_at > '2022-11-15'")
    policies.each do |p|
      address_string = p.primary_insurable&.addresses&.first&.full
      p.update_columns(address: address_string)
      Rails.logger.info "#DEBUG #{address_string}"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
