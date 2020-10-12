class AddOrderToFaq < ActiveRecord::Migration[5.2]
  def change
    add_column    :faqs, :faq_order, :integer, default: 0
    add_column    :faq_questions, :question_order, :integer, default: 0

    #need to save current order in default values
    Faq.reset_column_information
    FaqQuestion.reset_column_information

    brandings = Faq.pluck(:branding_profile_id).uniq
    brandings.each do |branding_id|

      Faq.where(branding_profile_id: branding_id).order(id: :asc).find_in_batches(batch_size: 100) do |faqs|
        Faq.transaction do
          faqs.each_with_index do |faq, index|
            faq.update(faq_order: index)
            update_questions(faq.id)
          end
        end

      end
    end

    end

  private

  def update_questions(faq_id)
    FaqQuestion.where(faq_id: faq_id).order(id: :asc).find_in_batches(batch_size: 100) do |faq_questions|
      FaqQuestion.transaction do
        faq_questions.each_with_index do |question, index|
          question.update(question_order: index)
        end
      end

    end
  end

  end


