class AddStiToReport< ActiveRecord::Migration[5.2]
  def change
    add_column :reports, :type, :string
    remove_column :reports, :format
  end
end
