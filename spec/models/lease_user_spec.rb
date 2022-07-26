# frozen_string_literal: true

# == Schema Information
#
# Table name: lease_users
#
#  id           :bigint           not null, primary key
#  primary      :boolean          default(FALSE)
#  lease_id     :bigint
#  user_id      :bigint
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  lessee       :boolean          default(TRUE), not null
#  moved_in_at  :date
#  moved_out_at :date
#
RSpec.describe LeaseUser, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
