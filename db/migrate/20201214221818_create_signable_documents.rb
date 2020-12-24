class CreateSignableDocuments < ActiveRecord::Migration[5.2]
  def change
    create_table :signable_documents do |t|
      # basic data
      t.string :title, null: false
      t.integer :document_type, null: false
      t.jsonb :document_data
      # signing data
      t.integer :status, null: false, default: 0
      t.boolean :errored, null: false, default: false
      t.jsonb :error_data
      t.datetime :signed_at
      # associations
      t.references :signer, polymorphic: true
      t.references :referent, polymorphic: true

      t.timestamps
    end
    
    add_index :signable_documents, [:status, :referent_type, :referent_id], name: "signable_documents_signed_index"
  end
end
