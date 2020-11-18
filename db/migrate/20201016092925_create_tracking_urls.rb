class CreateTrackingUrls < ActiveRecord::Migration[5.2]
  def change
    create_table :tracking_urls do |t|
      t.string :tracking_url
      t.integer :landing_page
      t.string :campaign_source
      t.string :campaign_medium
      t.string :campaign_term
      t.text :campaign_content
      t.string :campaign_name
      t.boolean :deleted, default: false

      t.references :agency

      t.timestamps
    end
  end
end
