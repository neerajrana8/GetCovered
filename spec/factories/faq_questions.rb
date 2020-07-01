FactoryBot.define do
  factory :faq_question do
    question { "MyText" }
    answer { "MyText" }
    association :faq, factory: :faq
  end
end
