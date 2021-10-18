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
      self.tokens = tokens.sort do |a, b|

        a_converted = a[1][:updated_at]&.to_datetime || a[1]['updated_at']&.to_datetime
        b_converted = b[1][:updated_at]&.to_datetime || b[1]['updated_at']&.to_datetime
        if a_converted && b_converted
          a_converted <=> b_converted
        else
          a_converted ? -1 : 1
        end
      end.to_h

      # Since the tokens are sorted by expiry, shift the oldest client token
      #   off the Hash until it no longer exceeds the maximum number of clients
      tokens.shift while max_client_tokens_exceeded?
    end
  end
end
