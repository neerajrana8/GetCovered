class Integration < ApplicationRecord
  belongs_to :integratable, polymorphic: true
end
