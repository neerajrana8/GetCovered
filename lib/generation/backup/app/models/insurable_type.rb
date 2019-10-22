class InsurableType < ApplicationRecord
	include ElasticsearchSearchable
	has_many :insurables
	has_many :carrier_insurable_types

  enum category: %w[property entity]

end
