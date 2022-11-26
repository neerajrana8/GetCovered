# == Schema Information
#
# Table name: access_tokens
#
#  id          :bigint           not null, primary key
#  key         :string
#  secret      :string
#  secret_hash :string
#  secret_salt :string
#  enabled     :boolean
#  bearer_type :string
#  bearer_id   :bigint
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  access_type :integer          default("generic"), not null
#  access_data :jsonb
#  expires_at  :datetime
#
# Access Token Model
# file: app/models/access_token.rb

require 'bcrypt'
require 'securerandom'

class AccessToken < ApplicationRecord
  include BCrypt

  after_initialize :initialize_access_token
  before_create :set_access_token_key,
                :set_access_token_secret,
                :set_access_token_secret_salt,
                :set_access_token_secret_hash

  belongs_to :bearer,
             polymorphic: true

  has_many :events, as: :eventable

  enum access_type: {
    generic: 0,
    agency_integration: 1,
    carrier_integration: 2,
    document_signature: 3,
    application_access: 4
  }

  def expired?
    return(self.expires_at && Time.current > self.expires_at)
  end

  def self.from_urlparam(par)
    AccessToken.where(key: par.gsub('_s','/').gsub('_e','=')).take #CGI.unescape(par.gsub('_','%'))
  end

  def self.verify(token)
    to_return = false
    token_array = token.split(":")

    if token_array.length == 2
      token_key = token_array[0]
      token_secret = token_array[1]
      if AccessToken.exists?(key: token_key)
        token = AccessToken.find_by_key(token_key)
        to_return = token if token.check_secret(token_secret)
      end
    end

    return to_return
  end

  def to_urlparam
    "#{self.key.gsub('/','_s').gsub('=','_e')}" # we just ignore the secret_salt and secret_hash in this case, for now # CGI.escape(key).gsub('%','_')
  end

  def check_secret(public_secret)
    public_secret.to_s.crypt(secret_salt) == secret_hash && enabled?
  end

  private

  def initialize_access_token; end

  def set_access_token_key
    loop do
      self.key = SecureRandom.base64(16)
      break unless AccessToken.exists?(key: key) || self.key.include?(":")
    end
   end

  def set_access_token_secret
    loop do
      self.secret = SecureRandom.base64(36)
      break unless AccessToken.exists?(secret: secret) || self.secret.include?(":")
    end
  end

  def set_access_token_secret_salt
    loop do
      # Fix a heisenbug with the crypt function, description and solution I found there https://projects.theforeman.org/issues/24600
      self.secret_salt = SecureRandom.alphanumeric(16)
      break unless AccessToken.exists?(secret_salt: secret_salt)
    end
  end

  def set_access_token_secret_hash
    self.secret_hash = secret.to_s.crypt(secret_salt)
  end
end
