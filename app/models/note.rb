# == Schema Information
#
# Table name: notes
#
#  id            :bigint           not null, primary key
#  content       :text
#  excerpt       :string
#  visibility    :integer          default(0), not null
#  staff_id      :bigint
#  noteable_type :string
#  noteable_id   :bigint
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
class Note < ApplicationRecord
  belongs_to :staff
  belongs_to :noteable, polymorphic: true
end
