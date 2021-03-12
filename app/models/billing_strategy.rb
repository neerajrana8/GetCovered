class BillingStrategy < ApplicationRecord
  # Concerns

  include SetSlug

  # Active Record Callbacks

  before_save :check_lock

  # Associations

  belongs_to :agency
  belongs_to :carrier
  belongs_to :policy_type
  belongs_to :collector,
    polymorphic: true,
    optional: true

  has_many :fees, as: :assignable

  accepts_nested_attributes_for :fees

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
