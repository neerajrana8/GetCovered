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
class FaqQuestion < ApplicationRecord
  belongs_to :faq

  default_scope { order(question_order: :asc) }
end
