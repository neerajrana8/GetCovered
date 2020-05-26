class AddStyleToPages < ActiveRecord::Migration[5.2]
  def change
    add_column :pages, :styles, :jsonb
  end
end
