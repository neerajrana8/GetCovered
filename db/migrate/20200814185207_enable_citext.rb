class EnableCitext < ActiveRecord::Migration[5.2]
  def up
    enable_extension 'citext'
  end

  def down
    disable_extension 'citext'
  end
end
