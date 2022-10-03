# == Schema Information
#
# Table name: insurable_data
#
#  id                :bigint           not null, primary key
#  insurable_id      :bigint
#  uninsured_units   :integer
#  total_units       :integer
#  expiring_policies :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Cache for calculated insurable fields, used in dashboards and reports
class InsurableData < ApplicationRecord
  self.table_name = 'insurable_data'

  belongs_to :insurable
end
