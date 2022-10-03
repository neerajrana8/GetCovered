# frozen_string_literal: true

# == Schema Information
#
# Table name: policy_applications
#
#  id                          :bigint           not null, primary key
#  reference                   :string
#  external_reference          :string
#  effective_date              :date
#  expiration_date             :date
#  status                      :integer          default("started"), not null
#  status_updated_on           :datetime
#  fields                      :jsonb
#  questions                   :jsonb
#  carrier_id                  :bigint
#  policy_type_id              :bigint
#  agency_id                   :bigint
#  account_id                  :bigint
#  policy_id                   :bigint
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  billing_strategy_id         :bigint
#  auto_renew                  :boolean          default(TRUE)
#  auto_pay                    :boolean          default(TRUE)
#  policy_application_group_id :bigint
#  coverage_selections         :jsonb            not null
#  extra_settings              :jsonb
#  resolver_info               :jsonb
#  tag_ids                     :bigint           default([]), not null, is an Array
#  tagging_data                :jsonb
#  error_message               :string
#  branding_profile_id         :integer
#  internal_error_message      :string
#
RSpec.describe PolicyApplication, type: :model do
  it 'cannot add Insurable without address' do
    pending('should be fixed')
    agency = FactoryBot.create(:agency)
    account = FactoryBot.create(:account, agency: agency)
    carrier = Carrier.first
    carrier.agencies << [agency]
    policy_application = FactoryBot.create(:policy_application, carrier: carrier, agency: agency, account: account)
    insurable = FactoryBot.create(:insurable)
    insurable.addresses = []
    insurable.account = policy_application.account
    insurable.save
    
    catch(:no_address) do
      policy_application.insurables << insurable
    end
    
    expect(policy_application.insurables).to be_empty

    insurable.addresses << FactoryBot.create(:address)
    policy_application.insurables << insurable
    expect(policy_application.insurables).to_not be_empty
  end

  it 'insurables must belong to the same account' do
    pending('should be fixed')
    agency = FactoryBot.create(:agency)
    account = FactoryBot.create(:account, agency: agency)
    carrier = Carrier.first
    carrier.agencies << [agency]
    policy_application = FactoryBot.create(:policy_application, carrier: carrier, agency: agency, account: account)
    insurable = FactoryBot.create(:insurable)
    insurable.account = FactoryBot.create(:account)
    insurable.addresses << FactoryBot.create(:address)
    insurable.save
    begin
      policy_application.insurables << insurable
    rescue ActiveRecord::RecordInvalid
    end
    expect(policy_application.insurables).to be_empty
  end

end
