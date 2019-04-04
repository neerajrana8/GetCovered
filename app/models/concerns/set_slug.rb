#
# SetSlug Concern
# file: app/models/concerns/set_slug.rb

module SetSlug
  extend ActiveSupport::Concern

  included do
    before_validation :set_slug,
      unless: Proc.new { |obj| (!obj.respond_to?(:title) || obj.title.nil?) && (!obj.respond_to?(:name) || obj.name.nil?) }
  end

  def set_slug
    string = respond_to?(:title) ? title : name
    self.slug = string.downcase.strip.tr(' ', '-').gsub(/[^\w-]/, '')
  end
end