json.array! @branding_profile.faqs do |faq|
  json.id faq.id
  json.title faq.title
  json.branding_profile_id faq.branding_profile_id
  json.faq_order faq.faq_order
  json.questions faq.faq_questions do |faq_question|
    json.id faq_question.id
    json.question faq_question.question
    json.answer faq_question.answer
    json.question_order faq_question.question_order
  end
end
