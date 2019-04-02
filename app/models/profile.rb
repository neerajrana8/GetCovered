class Profile < ApplicationRecord
  belongs_to :profileable, polymorphic: true
end
