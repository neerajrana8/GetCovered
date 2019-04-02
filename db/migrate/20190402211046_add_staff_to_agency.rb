class AddStaffToAgency < ActiveRecord::Migration[5.2]
  def change
    add_reference :agencies, :staff
  end
end
