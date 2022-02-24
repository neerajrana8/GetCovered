class CarrierInsurableProfile < ApplicationRecord

  after_create_commit :set_qbe_id,
    if: Proc.new { |cip| cip.carrier_id == 1 }

  after_save :check_preferred_status

  belongs_to :carrier
  belongs_to :insurable

  has_many :insurable_rate_configurations,
    as: :configurable

  validate :traits_and_data_are_non_nil

  private
    def set_qbe_id

      return_status = false

      if external_carrier_id.nil?

        loop do
          self.external_carrier_id = "#{ Rails.application.credentials.qbe[:employee_id] }#{ rand(36**7).to_s(36).upcase }".truncate(8, omission: '')
          return_status = true

          break unless CarrierInsurableProfile.exists?(:external_carrier_id => self.external_carrier_id)
        end
      end

      update_column(:external_carrier_id, self.external_carrier_id) if return_status == true

      return return_status

    end

    def check_preferred_status
      if self.insurable.get_carrier_status(carrier_id) == :preferred &&
         self.insuralbe.preferred[self.carrier_id.to_s] == false

        self.insuralbe.preferred[self.carrier_id.to_s] = true
        self.insurable.save()
      end
    end

    def traits_and_data_are_non_nil
      # we allow blank, but not nil (because things will break if we call hash methods on nil)
      errors.add(:traits, I18n.t('insurable_type_model.cannot_be_blank')) if self.traits.nil?
      errors.add(:data, I18n.t('insurable_type_model.cannot_be_blank')) if self.data.nil?
    end
end
