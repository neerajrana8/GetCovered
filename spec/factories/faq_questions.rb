# == Schema Information
#
# Table name: faq_questions
#
#  id             :bigint           not null, primary key
#  question       :text
#  answer         :text
#  faq_id         :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  question_order :integer          default(0)
#
FactoryBot.define do
  factory :faq_question do
    question { "MyText" }
    answer { "MyText" }
    association :faq, factory: :faq
  end
end
