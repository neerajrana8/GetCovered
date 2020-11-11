class AddUnsignedDocumentsToPolicy < ActiveRecord::Migration[5.2]
  def change
    add_column :policies, :unsigned_documents, :bigint, array: true, null: false, default: []
    add_index :policies, 'cardinality(unsigned_documents), status, carrier_id', name: "policies_unsigned_documents_index"
  end
end
