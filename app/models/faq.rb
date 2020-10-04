class Faq < ApplicationRecord
  belongs_to :branding_profile
  has_many :faq_questions

  accepts_nested_attributes_for :faq_questions

  default_scope { order(faq_order: :asc) }
end
