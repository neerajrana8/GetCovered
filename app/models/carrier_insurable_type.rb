class CarrierInsurableType < ApplicationRecord
  belongs_to :carrier
  belongs_to :insurable_type
  
  validate :traits_and_data_are_non_nil
  
  private
  
    def traits_and_data_are_non_nil
      # we allow blank, but not nil (because things will break if we call hash methods on nil)
      errors.add(:profile_traits, "cannot be null") if self.profile_traits.nil?
      errors.add(:profile_data, "cannot be null") if self.profile_data.nil?
    end
end
