# frozen_string_literal: true

class LineItem < ApplicationRecord
  belongs_to :invoice

  validates_presence_of :title
end
