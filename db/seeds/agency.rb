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

@agency = Agency.new(title: "Get Covered", 
										 enabled: true, 
										 whitelabel: true, 
										 tos_accepted: true, 
										 tos_accepted_at: Time.current, 
										 tos_acceptance_ip: nil, 
										 verified: false, 
										 stripe_id: nil, 
										 master_agency: true,
										 addresses_attributes: [
											 {
												 street_number: "265",
												 street_name: "Canal St",
												 street_two: "#205",
												 city: "New York",
												 state: "NY",
												 county: "NEW YORK",
												 zip_code: "10013",
												 primary: true
											 }
										 ])

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
    
    #
    # QBE Billing Strategies
    if @index == 1
      qbe_fee_example = { title: "Service Fee", amount: 10, amount_type: 1, type: 3, per_payment: true, ownerable: @agency}
      
      @agency.billing_strategies.create!(title: 'Annually', enabled: true, carrier: c, 
                                        policy_type: PolicyType.find(@index), 
                                        fees_attributes: [qbe_fee_example])
                                        
      @agency.billing_strategies.create!(title: 'Bi-Annually', enabled: true, 
                                        new_business: { payments: [50, 0, 0, 0, 0, 0, 59, 0, 0, 0, 0, 0], 
                                                        payments_per_term: 2, remainder_added_to_deposit: true },
                                        carrier: c, policy_type: PolicyType.find(@index), 
                                        fees_attributes: [qbe_fee_example])
                                        
      @agency.billing_strategies.create!(title: 'Quarterly', enabled: true, 
                                        new_business: { payments: [25, 0, 0, 25, 0, 0, 25, 0, 0, 25, 0, 0], 
                                                        payments_per_term: 4, remainder_added_to_deposit: true },
                                        carrier: c, policy_type: PolicyType.find(@index), 
                                        fees_attributes: [qbe_fee_example])
                                        
      @agency.billing_strategies.create!(title: 'Monthly', enabled: true, 
                                        new_business: { payments: [22.01, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09], 
                                                        payments_per_term: 12, remainder_added_to_deposit: true },
                                        renewal: { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33], 
                                                        payments_per_term: 12, remainder_added_to_deposit: true },
                                        carrier: c, policy_type: PolicyType.find(@index), 
                                        fees_attributes: [qbe_fee_example])
    end  
    
    @index += 1
  end
  
  @agency.commission_strategies.create(carrier: Carrier.find(1), policy_type: PolicyType.find(1), amount: 30, type: 0, house_override: 0)
  @agency.commission_strategies.create(carrier: Carrier.find(2), policy_type: PolicyType.find(2), amount: 22, type: 0, house_override: 0)
  @agency.commission_strategies.create(carrier: Carrier.find(3), policy_type: PolicyType.find(3), amount: 15, type: 0, house_override: 0)  
end