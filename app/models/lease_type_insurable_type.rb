# == Schema Information
#
# Table name: lease_type_insurable_types
#
#  id                :bigint           not null, primary key
#  enabled           :boolean          default(TRUE)
#  lease_type_id     :bigint
#  insurable_type_id :bigint
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class LeaseTypeInsurableType < ApplicationRecord
  belongs_to :lease_type
  belongs_to :insurable_type
end
