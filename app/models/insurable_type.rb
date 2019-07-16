class InsurableType < ApplicationRecord

	has_many :insurables
	has_many :carrier_insurable_types

  enum category: %w[property entity]

end
