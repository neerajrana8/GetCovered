module DeviseCustomUser
  extend ActiveSupport::Concern
  include DeviseTokenAuth::Concerns::User

  # redefine method from DeviseTokenAuth::Concerns::User to prevent recreating expiry
  def create_new_auth_token(client = nil)
    now = Time.zone.now

    last_token = tokens.fetch(client, {})

    token_params = {
      client: client,
      last_token: last_token['token'],
      updated_at: now
    }

    token_params[:expiry] = last_token['expiry'] if last_token['expiry'].present?
    
    token = create_token(**token_params)

    update_auth_header(token.token, token.client)
  end

  protected

  # remove the oldest used token instead of the first expired
  def clean_old_tokens
    if tokens.present? && max_client_tokens_exceeded?
      # Using Enumerable#sort_by on a Hash will typecast it into an associative
      #   Array (i.e. an Array of key-value Array pairs). However, since Hashes
      #   have an internal order in Ruby 1.9+, the resulting sorted associative
      #   Array can be converted back into a Hash, while maintaining the sorted
      #   order.
      self.tokens = tokens.sort_by { |_cid, v| v[:updated_at]&.to_datetime || v['updated_at']&.to_datetime }.to_h

      # Since the tokens are sorted by expiry, shift the oldest client token
      #   off the Hash until it no longer exceeds the maximum number of clients
      tokens.shift while max_client_tokens_exceeded?
    end
  end
end
