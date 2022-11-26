# frozen_string_literal: true

class UpdatePoliciesBoundStatus < ActiveRecord::Migration[6.1]
  def up
    Policy.where(status: "BOUND", policy_in_system: false).find_in_batches(batch_size: 100) do |policies|
      Policy.transaction do
        policies.each do |policy|
          policy.update(status: "EXTERNAL_VERIFIED")
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
