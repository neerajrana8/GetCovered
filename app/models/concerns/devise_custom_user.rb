module DeviseCustomUser
  extend ActiveSupport::Concern
  include DeviseTokenAuth::Concerns::User

  # redefine method from DeviseTokenAuth::Concerns::User to prevent recreating expiry
  def create_new_auth_token(client = nil)
    now = Time.zone.now

    last_token = tokens.fetch(client, {})
    token = create_token(
      client: client,
      last_token: last_token['token'],
      updated_at: now,
      expiry: last_token['expiry']
    )

    update_auth_header(token.token, token.client)
  end
end
