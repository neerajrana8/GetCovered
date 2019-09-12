# Seeding Functions
#

module SeedFunctions
	def self.adduser(user_type, chash)
	  @user = user_type.new(chash)
	  @user.invite! do |u|
	    u.skip_invitation = true
	  end
	  token = Devise::VERSION >= "3.1.0" ? @user.instance_variable_get(:@raw_invitation_token) : @user.invitation_token
	  user_type.accept_invitation!({invitation_token: token}.merge(chash))
	  @user
	end
	
	def self.time_rand(from = 0.0, to = Time.now)
  	return Time.at(from + rand * (to.to_f - from.to_f))
	end
end