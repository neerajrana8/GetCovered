##
# =Branding Profile Attribute Model
# file: +app/models/branding_profile_attribute.rb+

class BrandingProfileAttribute < ApplicationRecord  
  include ActionView::Helpers::SanitizeHelper
  ALLOWED_TAGS = ["strong", "em", "b", "i", "p", "code", "pre", "tt", "samp", "kbd", "var", "sub", "sup", "dfn", "cite",
                  "big", "small", "address", "hr", "br", "div", "span", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol",
                  "li", "dl", "dt", "dd", "abbr", "acronym", "a", "img", "blockquote", "del", "ins"]

  ALLOWED_ATTRIBUTES = ["style", "href", "src", "width", "height", "alt", "cite", "datetime", "title", "class", "name",
                        "xml:lang", "abbr"]
  
  belongs_to :branding_profile

  # Turned off for now, because sanitizing inline svg
  # before_save :sanitize_content

  def sanitize_content
    self.value = sanitize value, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES 
  end

end