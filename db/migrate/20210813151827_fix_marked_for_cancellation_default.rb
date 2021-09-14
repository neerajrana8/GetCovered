class FixMarkedForCancellationDefault < ActiveRecord::Migration[5.2]
  def change
    change_column_default :policies, :marked_for_cancellation, false
  end
end
