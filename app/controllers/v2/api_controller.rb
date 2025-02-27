module V2
  # API Controller
  class ApiController < ApplicationController
    include DeviseTokenAuth::Concerns::SetUserByToken
    respond_to :json

    class ApiError < StandardError; end

    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ApiError, with: :handle_exception

    def generate_cache_key(key, payload)
      token = []
      token << key
      payload.each do |v|
        token << v.map { |k| k }
      end
      cache_key = token.join('_')
      cache_key
    end

    def not_found(exception)
      render json: { errors: [ exception.model => "Record not found ID=#{exception.id}" ] }, status: 404
    end

    def not_found_error(message)
      render json: { message: message, errors: [ :record_not_found ] }, status: 404
    end

    def params_error(message = nil)
      render json: { message: message, errors: [ :not_enough_params ] }, status: 400
    end

    def handle_exception(message)
      render json: { error: message }, status: 400
    end

    def raise_error(message)
      raise ApiError, message
    end
  end
end
