# frozen_string_literal: true

# == Schema Information
#
# Table name: line_items
#
#  id                           :bigint           not null, primary key
#  title                        :string           not null
#  priced_in                    :boolean          default(FALSE), not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  original_total_due           :integer          not null
#  total_due                    :integer          not null
#  total_reducing               :integer          default(0), not null
#  total_received               :integer          default(0), not null
#  preproration_total_due       :integer          not null
#  duplicatable_reduction_total :integer          default(0), not null
#  chargeable_type              :string
#  chargeable_id                :bigint
#  invoice_id                   :bigint
#  analytics_category           :integer          default("other"), not null
#  policy_quote_id              :bigint
#  policy_id                    :bigint
#  archived_line_item_id        :bigint
#  hidden                       :boolean          default(FALSE), not null
#
RSpec.describe LineItem, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
