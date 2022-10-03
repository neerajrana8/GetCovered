# == Schema Information
#
# Table name: carrier_class_codes
#
#  id               :bigint           not null, primary key
#  external_id      :integer
#  major_category   :string
#  sub_category     :string
#  class_code       :string
#  appetite         :boolean          default(FALSE)
#  search_value     :string
#  sic_code         :string
#  eq               :string
#  eqsl             :string
#  industry_program :string
#  naics_code       :string
#  state_code       :string
#  enabled          :boolean          default(FALSE)
#  carrier_id       :bigint
#  policy_type_id   :bigint
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
class CarrierClassCode < ApplicationRecord
  belongs_to :carrier
  belongs_to :policy_type
  
  validate :one_enabled_class_code_at_a_time
  
  private
  
    def one_enabled_class_code_at_a_time
      if CarrierClassCode.where(class_code: self.class_code, state_code: self.state_code, enabled: true).count > 0
        errors.add(:class_code, "already exists and is enabled for state code")
      end  
    end
end
