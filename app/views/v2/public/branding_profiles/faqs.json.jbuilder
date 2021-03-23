json.array! @branding_profile.faqs.where(language: I18n.locale) do |faq|
  json.id faq.id
  json.title faq.title
  json.language faq.language
  json.branding_profile_id faq.branding_profile_id
  json.questions faq.faq_questions do |faq_question|
    json.id faq_question.id
    json.question faq_question.question
    json.answer faq_question.answer
  end
end
