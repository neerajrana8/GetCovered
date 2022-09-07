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
class LineItem < ApplicationRecord
  include FinanceAnalyticsCategory # provides analytics_category enum

  belongs_to :invoice
  belongs_to :chargeable,
    polymorphic: true,
    autosave: true
  belongs_to :policy_quote,
    optional: true
  belongs_to :policy,
    optional: true
    
  has_many :line_item_changes
  has_many :line_item_reductions

  validates_presence_of :title
  validates_inclusion_of :priced_in, in: [true, false]
  validates :original_total_due, numericality: { greater_than_or_equal_to: 0 }
  validates :preproration_total_due, numericality: { greater_than_or_equal_to: 0 }
  validates :total_due, numericality: { greater_than_or_equal_to: 0 }
  validates :total_received, numericality: { greater_than_or_equal_to: 0 }
  validates :duplicatable_reduction_total, numericality: { greater_than_or_equal_to: 0 }
  
  scope :priced_in, -> { where(priced_in: true) }

  # sort line items from first-to-charge-for to last-to-charge-for
  def <=>(other)
    return (self.id || 0) <=> (other.id || 0) if self.analytics_category == other.analytics_category
    return -(self.analytics_category <=> other.analytics_category) # negative so tax gets paid first
  end
    
    
end
