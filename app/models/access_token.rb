# Access Token Model
# file: app/models/access_token.rb

require 'bcrypt'
require 'securerandom'

class AccessToken < ApplicationRecord
  include BCrypt
  
  after_initialize  :initialize_access_token
	before_create     :set_access_token_key,
										:set_access_token_secret,
										:set_access_token_secret_salt,
										:set_access_token_secret_hash
										
  belongs_to :bearer, 
  	polymorphic: true
  
  def check_secret(public_secret)
		return public_secret.to_s.crypt(secret_salt) == secret_hash && enabled?
	end
  
  private
  	def initialize_access_token
	  			
	  end
	  
	  def set_access_token_key
      loop do
        self.key = SecureRandom.base64(16)
        break unless AccessToken.exists?(:key => self.key)
      end
		end
		
		def set_access_token_secret
			loop do
				self.secret	= SecureRandom.base64(36)
        break unless AccessToken.exists?(:secret => self.secret)
      end
		end
		
		def set_access_token_secret_salt
      loop do
        self.secret_salt = SecureRandom.base64(36)
        break unless AccessToken.exists?(:secret_salt => self.secret_salt)
      end
		end
		
		def set_access_token_secret_hash
			ap "Self secret: #{self.secret}"
			self.secret_hash = self.secret.to_s.crypt(self.secret_salt)
		end
end
