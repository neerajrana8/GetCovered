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
end
