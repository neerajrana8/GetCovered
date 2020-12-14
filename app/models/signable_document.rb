class SignableDocument < ApplicationRecord
  belongs_to :signer, polymorphic: true
  belongs_to :referent, polymorphic: true
end
