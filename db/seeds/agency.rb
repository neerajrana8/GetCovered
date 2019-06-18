# Get Covered Agency Seed Setup File
# file: db/seeds/agency.rb


def adduser(user_type, chash)
  @user = user_type.new(chash)
  @user.invite! do |u|
    u.skip_invitation = true
  end
  token = Devise::VERSION >= "3.1.0" ? @user.instance_variable_get(:@raw_invitation_token) : @user.invitation_token
  user_type.accept_invitation!({invitation_token: token}.merge(chash))
  @user
end

@agency = Agency.new(title: "Get Covered", enabled: true, whitelabel: true, tos_accepted: true, tos_accepted_at: Time.current, tos_acceptance_ip: nil, verified: false, stripe_id: nil, master_agency: true)

if @agency.save
  @site_staff = [
    { email: 'dylan@getcoveredllc.com', password: 'TestingPassword1234', password_confirmation: 'TestingPassword1234', role: 'agent', enabled: true, organizable: @agency, profile_attributes: { first_name: 'Dylan', last_name: 'Gaines' }}
  ]
  
  @site_staff.each do |staff|
    adduser(Staff, staff)
  end
  
  @index = 1
  
  Carrier.find_each do |c|  
    @agency.carriers << c 
    carrier_agency = CarrierAgency.where(carrier: c, agency: @agency).take
    
    51.times do |state|
      available = state == 0 || state == 11 ? false : true
      authorization = CarrierAgencyAuthorization.create(state: state, available: available, carrier_agency: carrier_agency, policy_type: PolicyType.find(@index))
      Fee.create(title: "Service Fee", type: :MISC, per_payment: true, amount: 8, amount_type: :PERCENTAGE, enabled: true, assignable: authorization, ownerable: @agency)
    end    
    
    @index += 1
  end
  
  @agency.commission_strategies.create(carrier: Carrier.find(1), policy_type: PolicyType.find(1), amount: 30, type: 0, house_override: 0)
  @agency.commission_strategies.create(carrier: Carrier.find(2), policy_type: PolicyType.find(2), amount: 22, type: 0, house_override: 0)
  @agency.commission_strategies.create(carrier: Carrier.find(3), policy_type: PolicyType.find(3), amount: 15, type: 0, house_override: 0)  
end