class AddFieldsToLeadEvents < ActiveRecord::Migration[5.2]
  def change
    add_reference :lead_events, :policy_type
    add_reference :lead_events, :agency
  end
end
