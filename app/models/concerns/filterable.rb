# Filterable Concern
# file: +app/models/concerns/filterable.rb+

module Filterable
  extend ActiveSupport::Concern
  module ClassMethods
    def filter(filtering_params)
      results = self.where(nil) # create an anonymous scope
      filtering_params&.each do |key, value|
        results = results.public_send("filter_by_#{key}", value) unless value.nil?
      end
      results
    end
  end
end
