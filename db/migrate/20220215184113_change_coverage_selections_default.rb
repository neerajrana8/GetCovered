class ChangeCoverageSelectionsDefault < ActiveRecord::Migration[6.1]
  def change
    change_column_default :policy_applications, :coverage_selections, from: [], to: {}
  end
end
