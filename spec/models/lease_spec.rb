# frozen_string_literal: true

# == Schema Information
#
# Table name: leases
#
#  id               :bigint           not null, primary key
#  reference        :string
#  start_date       :date
#  end_date         :date
#  status           :integer          default("pending")
#  covered          :boolean          default(FALSE)
#  lease_type_id    :bigint
#  insurable_id     :bigint
#  account_id       :bigint
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  expanded_covered :jsonb
#  defunct          :boolean          default(FALSE), not null
#
RSpec.describe Lease, elasticsearch: true, type: :model do
  it 'Set occupied status for unit if lease was added' do
    insurable = FactoryBot.create(:insurable, :residential_unit)
    expect { FactoryBot.create(:lease, insurable: insurable) }.to change { insurable.occupied }.from(false).to(true)
  end

  it 'Unset occupied status for unit if lease was expired' do
    insurable = FactoryBot.create(:insurable, :residential_unit)
    lease = FactoryBot.create(:lease, insurable: insurable)
    expect { lease.update(end_date: Time.zone.now - 1.day) }.to change { insurable.occupied }.from(true).to(false)
  end
end
