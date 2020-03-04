class Page < ApplicationRecord
  include ActionView::Helpers::SanitizeHelper

  belongs_to :agency

  before_save :sanitize_content

  def sanitize_content
    self.content = sanitize content
  end
end
