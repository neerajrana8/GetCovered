# Cache for calculated insurable fields, used in dashboards and reports
class InsurableData < ApplicationRecord
  self.table_name = 'insurable_data'

  belongs_to :insurable
end
