class AddOccurrenceLimitToPolicyCoverage < ActiveRecord::Migration[6.1]
  def change
    add_column :policy_coverages, :occurrence_limit, :integer
  end
end
