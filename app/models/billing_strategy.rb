# == Schema Information
#
# Table name: billing_strategies
#
#  id             :bigint           not null, primary key
#  title          :string
#  slug           :string
#  enabled        :boolean          default(FALSE), not null
#  new_business   :jsonb
#  renewal        :jsonb
#  locked         :boolean          default(FALSE), not null
#  agency_id      :bigint
#  carrier_id     :bigint
#  policy_type_id :bigint
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  carrier_code   :string
#
class BillingStrategy < ApplicationRecord
  # Concerns

  include SetSlug

  # Active Record Callbacks

  before_save :check_lock

  # Associations

  belongs_to :agency
  belongs_to :carrier
  belongs_to :policy_type

  has_many :fees, as: :assignable

  accepts_nested_attributes_for :fees

  # Scopes

  scope :enabled, -> { where(enabled: true) }

  # Validations

  validates_presence_of :title, :slug
  validate :carrier_accepts_policy_type
  validate :agency_authorized_for_carrier

  private

    def check_lock
      unless locked? && locked_was == false
        raise ActiveRecord::ReadOnlyRecord if locked?
      end
    end

    def carrier_accepts_policy_type
      errors.add(:policy_type, "#{I18n.t('billing_strategy_model.must_be_assigned_to_carrier')} #{ carrier.title }") unless carrier.policy_types.include?(policy_type)
    end

    def agency_authorized_for_carrier
      errors.add(:agency, "#{I18n.t('billing_strategy_model.must_be_assigned_to_carrier')} #{ carrier.title }") unless carrier.agencies.include?(agency)
    end
end
