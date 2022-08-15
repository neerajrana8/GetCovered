# == Schema Information
#
# Table name: carrier_insurable_types
#
#  id                :bigint           not null, primary key
#  profile_traits    :jsonb
#  profile_data      :jsonb
#  enabled           :boolean          default(FALSE), not null
#  carrier_id        :bigint
#  insurable_type_id :bigint
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class CarrierInsurableType < ApplicationRecord
  belongs_to :carrier
  belongs_to :insurable_type

  validate :traits_and_data_are_non_nil

  private

    def traits_and_data_are_non_nil
      # we allow blank, but not nil (because things will break if we call hash methods on nil)
      errors.add(:profile_traits, I18n.t('carrier_insurable_type_model.cannot_be_null')) if self.profile_traits.nil?
      errors.add(:profile_data, I18n.t('carrier_insurable_type_model.cannot_be_null')) if self.profile_data.nil?
    end
end
