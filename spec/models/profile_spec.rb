# frozen_string_literal: true

# == Schema Information
#
# Table name: profiles
#
#  id               :bigint           not null, primary key
#  first_name       :string
#  last_name        :string
#  middle_name      :string
#  title            :string
#  suffix           :string
#  job_title        :string
#  full_name        :string
#  contact_email    :string
#  contact_phone    :string
#  birth_date       :date
#  profileable_type :string
#  profileable_id   :bigint
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  gender           :integer          default("unspecified")
#  salutation       :integer          default("unspecified")
#  language         :integer          default("en")
#
RSpec.describe Profile, elasticsearch: true, type: :model do
  pending "#{__FILE__} Needs to be updated after removing elasticsearch tests"
end
