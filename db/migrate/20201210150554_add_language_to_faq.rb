class AddLanguageToFaq < ActiveRecord::Migration[5.2]
  def change
    add_column :faqs, :language, :integer, default: 0
  end
end
