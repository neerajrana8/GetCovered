# == Schema Information
#
# Table name: policy_rates
#
#  id                    :bigint           not null, primary key
#  policy_id             :bigint
#  policy_quote_id       :bigint
#  insurable_rate_id     :bigint
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  policy_application_id :bigint
#
class PolicyRate < ApplicationRecord
  belongs_to :policy, optional: true
  belongs_to :policy_quote, optional: true
  belongs_to :policy_application
  belongs_to :insurable_rate
end
