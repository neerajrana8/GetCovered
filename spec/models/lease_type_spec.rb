# frozen_string_literal: true

# == Schema Information
#
# Table name: lease_types
#
#  id         :bigint           not null, primary key
#  title      :string
#  enabled    :boolean          default(FALSE)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
RSpec.describe LeaseType, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
