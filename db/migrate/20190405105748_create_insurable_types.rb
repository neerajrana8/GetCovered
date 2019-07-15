class CreateInsurableTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :insurable_types do |t|
      t.string        :title
      t.string        :slug
      t.integer       :category
      t.boolean       :enabled
      t.timestamps
    end
  end
end