class ModelError < ApplicationRecord
  belongs_to :model, polymorphic: true
end
