# Filterable Concern
# file: +app/models/concerns/filterable.rb+

module Filterable
  extend ActiveSupport::Concern

  module ClassMethods
    def filter(params)
      to_return = self.all
      unless params.blank?
        params.each do |key, value|
          if value.class == Hash
            # Handle specially formatted search terms
            if value.has_key?(:like)
              to_return = to_return.where("#{key} LIKE ?", "%#{value[:like]}%")
            end
          else
            # Put hash stuff in
            to_return = to_return.where(Hash[key, value])
          end
        end
      end
      return(to_return)
    end
  end
end
