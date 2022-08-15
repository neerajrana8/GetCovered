# == Schema Information
#
# Table name: change_requests
#
#  id                :bigint           not null, primary key
#  reason            :text
#  customized_action :integer          default("decline")
#  method            :string
#  field             :string
#  current_value     :string
#  new_value         :string
#  status            :integer          default("awaiting_confirmation")
#  status_changed_on :datetime
#  staff_id          :bigint
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  changeable_type   :string
#  requestable_id    :integer
#  requestable_type  :string
#  changeable_id     :integer
#
# require 'rails_helper'

# RSpec.describe ChangeRequest, type: :model do
#   pending "add some examples to (or delete) #{__FILE__}"
# end
