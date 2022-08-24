# == Schema Information
#
# Table name: faqs
#
#  id                  :bigint           not null, primary key
#  title               :string
#  branding_profile_id :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  faq_order           :integer          default(0)
#  language            :integer          default("en")
#
class Faq < ApplicationRecord
  belongs_to :branding_profile
  has_many :faq_questions, dependent: :destroy
  accepts_nested_attributes_for :faq_questions

  enum language: { en: 0, es: 1 }

  default_scope { order(faq_order: :asc) }
end
