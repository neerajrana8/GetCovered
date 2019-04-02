class Account < ApplicationRecord
  belongs_to :staff
  belongs_to :agency
end
