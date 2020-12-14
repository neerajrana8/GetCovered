class CreateSignableDocuments < ActiveRecord::Migration[5.2]
  def change
    create_table :signable_documents do |t|
      t.string :title
      t.enum :document_type
      t.jsonb :document_data
      t.boolean :signed
      t.datetime :signed_at
      t.references :signer, polymorphic: true
      t.references :referent, polymorphic: true

      t.timestamps
    end
  end
end
