module V2
  # API Controller
  class ApiController < ApplicationController
    def generate_cache_key(key, payload)
      token = []
      token << key
      payload.each do |v|
        token << v.map { |k| k }
      end
      cache_key = token.join('_')
      cache_key
    end
  end
end
