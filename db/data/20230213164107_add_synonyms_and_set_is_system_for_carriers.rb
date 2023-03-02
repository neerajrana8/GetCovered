# frozen_string_literal: true

class AddSynonymsAndSetIsSystemForCarriers < ActiveRecord::Migration[6.1]
  def up
    Carrier.find_by(title: 'Millenial Specialty Insurance')&.update(synonyms: 'MSI,')
    Carrier.find_by(title: 'Queensland Business Insurance')&.update(synonyms: 'QBE,')

    Carrier.update_all(is_system: true)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
