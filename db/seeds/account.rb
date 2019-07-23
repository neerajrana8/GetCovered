# Get Covered Account Seed Setup File
# file: db/seeds/account.rb


def adduser(user_type, chash)
  @user = user_type.new(chash)
  @user.invite! do |u|
    u.skip_invitation = true
  end
  token = Devise::VERSION >= "3.1.0" ? @user.instance_variable_get(:@raw_invitation_token) : @user.invitation_token
  user_type.accept_invitation!({invitation_token: token}.merge(chash))
  @user
end

@agency = Agency.find(1)
@account = @agency.accounts.new(title: "Rent OS", 
																enabled: true, 
																whitelabel: true, 
																tos_accepted: true, 
																tos_accepted_at: Time.current, 
																tos_acceptance_ip: nil, 
																verified: false, 
																stripe_id: nil,
																addresses_attributes: [
																	{
																		street_number: "3201",
																		street_name: "S. Bentley Ave",
																		city: "Los Angeles",
																		state: "CA",
																		county: "LOS ANGELES",
																		zip_code: "90034",
																		primary: true
																	}
																])

if @account.save
  @site_staff = [
    { email: 'dylan@rent-os.com', password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: @account, profile_attributes: { first_name: 'Dylan', last_name: 'Gaines', job_title: 'Chief Technical Officer' }},
    { email: 'brandon@rent-os.com', password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: @account, profile_attributes: { first_name: 'Brandon', last_name: 'Tobman', job_title: 'Chief Executive Officer' }}
  ]
  
  @site_staff.each do |staff|
    adduser(Staff, staff)
  end
  
  @account.update(staff_id: @account.staff.first.id)
end