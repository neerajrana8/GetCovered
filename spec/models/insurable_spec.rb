# == Schema Information
#
# Table name: insurables
#
#  id                       :bigint           not null, primary key
#  title                    :string
#  slug                     :string
#  enabled                  :boolean          default(FALSE)
#  account_id               :bigint
#  insurable_type_id        :bigint
#  insurable_id             :bigint
#  category                 :integer          default("property")
#  covered                  :boolean          default(FALSE)
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  agency_id                :bigint
#  policy_type_ids          :bigint           default([]), not null, is an Array
#  preferred_ho4            :boolean          default(FALSE), not null
#  confirmed                :boolean          default(TRUE), not null
#  occupied                 :boolean          default(FALSE)
#  expanded_covered         :jsonb            not null
#  preferred                :jsonb
#  additional_interest      :boolean          default(FALSE)
#  additional_interest_name :string
#  minimum_liability        :integer
#
require 'rails_helper'

RSpec.describe Insurable, elasticsearch: true, type:  :model do
  it 'should belong to same Account if it has insurable parent' do
    account = FactoryBot.create(:account)
    insurable = FactoryBot.create(:insurable)
    child_insurable = insurable.insurables.create(
      title: 'New test insurable',
      account: account,
      insurable_type_id: InsurableType::RESIDENTIAL_UNITS_IDS.first
    )
    expect(child_insurable).to_not be_valid
    child_insurable.errors[:account].should include('must belong to same account as parent')
    
    child_insurable.account = insurable.account
    child_insurable.save
    expect(child_insurable).to be_valid
  end
end
