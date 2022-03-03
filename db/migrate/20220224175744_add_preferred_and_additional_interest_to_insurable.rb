class AddPreferredAndAdditionalInterestToInsurable < ActiveRecord::Migration[6.1]
  def change
    add_column :insurables, :preferred, :jsonb, default: {}
    add_column :insurables, :additional_interest, :boolean, default: false

    #    Insurable.reset_column_information
    #
    #    Insurable.find_each do |insurable|
    #      preferred_hash = {}
    #      [1, 5].each do |carrier_id|
    #        preferred_hash[carrier_id] = insurable.get_carrier_status(carrier_id) == :preferred ? true : false
    #      end
    #      insurable.update preferred: preferred_hash
    #    end
  end
end
