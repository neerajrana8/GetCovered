# frozen_string_literal: true

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
