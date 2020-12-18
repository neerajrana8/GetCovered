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
             
  enum access_type: {
    generic: 0,
    agency_integration: 1,
    carrier_integration: 2,
    document_signature: 3
  }
  
  def self.from_urlparam(par)
    AccessToken.where(key: par.gsub('_s','/').gsub('_e','=')).take #CGI.unescape(par.gsub('_','%'))
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
      break unless AccessToken.exists?(key: key)
    end
   end
    
  def set_access_token_secret
    loop do
      self.secret = SecureRandom.base64(36)
      break unless AccessToken.exists?(secret: secret)
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
