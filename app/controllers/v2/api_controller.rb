module V2
  # API Controller
  class ApiController < ApplicationController
    include DeviseTokenAuth::Concerns::SetUserByToken
    respond_to :json
    rescue_from ActiveRecord::RecordNotFound, with: :not_found

    def generate_cache_key(key, payload)
      token = []
      token << key
      payload.each do |v|
        token << v.map { |k| k }
      end
      cache_key = token.join('_')
      cache_key
    end

    def not_found
      render json: { errors: [ :record_not_found ] }, status: 404
    end


    def not_found_error(message)
      render json: { message: message, errors: [ :record_not_found ] }, status: 404
    end

    def params_error(message = nil)
      render json: { message: message, errors: [ :not_enough_params ] }, status: 400
    end
  end
end
