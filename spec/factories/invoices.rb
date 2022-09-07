# == Schema Information
#
# Table name: invoices
#
#  id                                   :bigint           not null, primary key
#  number                               :string           not null
#  description                          :text
#  available_date                       :date             not null
#  due_date                             :date             not null
#  created_at                           :datetime         not null
#  updated_at                           :datetime         not null
#  external                             :boolean          default(FALSE), not null
#  status                               :integer          not null
#  under_review                         :boolean          default(FALSE), not null
#  pending_charge_count                 :integer          default(0), not null
#  pending_dispute_count                :integer          default(0), not null
#  error_info                           :jsonb            not null
#  was_missed                           :boolean          default(FALSE), not null
#  was_missed_at                        :datetime
#  autosend_status_change_notifications :boolean          default(TRUE), not null
#  original_total_due                   :integer          default(0), not null
#  total_due                            :integer          default(0), not null
#  total_payable                        :integer          default(0), not null
#  total_reducing                       :integer          default(0), not null
#  total_pending                        :integer          default(0), not null
#  total_received                       :integer          default(0), not null
#  total_undistributable                :integer          default(0), not null
#  invoiceable_type                     :string
#  invoiceable_id                       :bigint
#  payer_type                           :string
#  payer_id                             :bigint
#  collector_type                       :string
#  collector_id                         :bigint
#  archived_invoice_id                  :bigint
#  status_changed                       :datetime
#
FactoryBot.define do
  factory :invoice do
    association :invoiceable, factory: :policy
    association :payer, factory: :user
    collector { Agency.find(1) }
    
    #collector_type { "Agency" }
    #collector_id { 1 }
    
    available_date { 1.day.ago }
    due_date { 1.day.from_now }
    external { false }
    status { 'available' }
    
    original_total_due { 0 }
    total_due { 0 }
    total_payable { 0 }
    
    after(:create) do |invoice|
      result = create(:line_item, invoice: invoice, chargeable: invoice.invoiceable)
      invoice.reload
      invoice.send(:mark_line_items_priced_in)
      invoice.line_items.each{|li| li.save! }
      invoice.save!
    end
  end
end
