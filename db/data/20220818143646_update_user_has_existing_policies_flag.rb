# frozen_string_literal: true

class UpdateUserHasExistingPoliciesFlag < ActiveRecord::Migration[6.1]
  def up
    User.includes(:policies).in_batches.each_record do |user|
      user.update(has_existing_policies: true) if user.policies.present?
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
