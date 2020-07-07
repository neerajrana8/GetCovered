class Faq < ApplicationRecord
  belongs_to :branding_profile
  has_many :faq_questions
end
