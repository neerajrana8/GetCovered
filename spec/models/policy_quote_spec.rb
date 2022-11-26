# == Schema Information
#
# Table name: policy_quotes
#
#  id                    :bigint           not null, primary key
#  reference             :string
#  external_reference    :string
#  status                :integer          default("awaiting_estimate")
#  status_updated_on     :datetime
#  policy_application_id :bigint
#  agency_id             :bigint
#  account_id            :bigint
#  policy_id             :bigint
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  est_premium           :integer
#  external_id           :string
#  policy_group_quote_id :bigint
#  carrier_payment_data  :jsonb
#
require 'rails_helper'

RSpec.describe PolicyQuote, elasticsearch: true, type:  :model do
  pending "#{__FILE__} Needs to be updated after removing elasticsearch tests"
end
