class CreateAssignments < ActiveRecord::Migration[5.2]
  def change
    create_table :assignments do |t|
      t.references :stuff
      t.references :assignable, polymorphic: true
      t.timestamps
    end
  end
end
