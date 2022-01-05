class FixPremiumTermNames < ActiveRecord::Migration[5.2]
  def change
    rename_column :policy_premia, :prorated_term_first_moment, :prorated_first_moment
    rename_column :policy_premia, :prorated_term_last_moment, :prorated_last_moment
  end
end
