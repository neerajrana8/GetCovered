class CreateFaqQuestions < ActiveRecord::Migration[5.2]
  def change
    create_table :faq_questions do |t|
      t.text :question
      t.text :answer
      t.integer :faq_id

      t.timestamps
    end
    add_index :faq_questions, :faq_id
  end
end
