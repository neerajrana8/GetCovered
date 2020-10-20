class AddStaffNotesToClaims < ActiveRecord::Migration[5.2]
  def change
    add_column :claims, :staff_notes, :text
  end
end
