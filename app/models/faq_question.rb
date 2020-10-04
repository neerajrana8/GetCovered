class FaqQuestion < ApplicationRecord
  belongs_to :faq

  default_scope { order(question_order: :asc) }
end
