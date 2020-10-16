require './db/seeds/functions'
require 'faker'
require 'socket'


puts "Initializing carrier ##{dc_id}..."

@create_test_insurables = ENV['create_test_insurables'] || false
@create_test_policies = ENV['create_test_policies'] || false


########################################################################
######################## BASIC CARRIER SETUP ###########################
########################################################################

@dc_id = 6

@residential_community = InsurableType.find(1)
@residential_unit = InsurableType.find(4)


@carrier = Carrier.where(id: @dc_id).take || Carrier.create!({
  title: "Deposit Choice",
  integration_designation: "dc",
  syncable: false,
  rateable: true,
  quotable: true,
  bindable: true,
  verifiable: false,
  enabled: true
})

# create CITs for communities and units
@cit_community = CarrierInsurableType.where(carrier: @carrier, insurable_type: @residential_community).take || CarrierInsurableType.create!({
  carrier: @carrier,
  insurable_type: @residential_community,
  enabled: true,
  profile_traits: {},
  profile_data: {
    "sought_dc_information" => false,
    "sought_dc_information_on" => nil,
    "got_dc_information" => false,
    "dc_information_event_id" => nil,
    "dc_address_id" => nil,
    "building_address_ids" => {},
    "dc_units_not_in_system" => [],
    "units_not_in_dc_system" => [],
    "units_ignored_for_lack_of_cip" => []
  }
})
@cit_unit = CarrierInsurableType.where(carrier: @carrier, insurable_type: @residential_unit).take || CarrierInsurableType.create!({
  carrier: @carrier, 
  insurable_type: @residential_unit, 
  enabled: true,
  profile_traits: {},
  profile_data: {
    "got_dc_information" => false,
    "dc_address_id" => nil,
    "dc_community_id" => nil,
    "dc_unit_id" => nil
  }
})

# set up policy type stuff

@policy_type = PolicyType.where(designation: "SECURITY-DEPOSIT").take || PolicyType.create!({
  title: "Security Deposit Replacement",
  designation: "SECURITY-DEPOSIT",
  enabled: true 
})

@cpt = CarrierPolicyType.where(carrier: @carrier, policy_type: @policy_type).take || CarrierPolicyType.create!({
  carrier: @carrier,
  policy_type: @policy_type,
  application_required: true,
  application_fields: [
    # MOOSE WARNING: occupants???
  ]
})

51.times do |state|
  available = (state == 0 || state == 11 ? false : true)
  cpa = CarrierPolicyTypeAvailability.create(state: state, available: available, carrier_policy_type: @cpt)
  # WARNING: fee disabled: cpa.fees.create(title: "Origination Fee", type: :ORIGINATION, amount: 2500, enabled: true, ownerable: @carrier) 
else
  pp @cpt.errors
end unless CarrierPolicyTypeAvailability.where(carrier_policy_type: @cpt).limit(1).count > 0


########################################################################
########################## GC AGENCY SETUP #############################
########################################################################


@get_covered = Agency.where(title: "Get Covered").take
carrier_agency = CarrierAgency.where(carrier: @carrier, agency: @get_covered).take
if carrier_agency.nil?
  @get_covered.carriers << @carrier
  carrier_agency = CarrierAgency.where(carrier: @carrier, agency: @get_covered).take
end
@fee_amount = nil # change to create service fees for states
51.times do |state|
  available = (state == 0 || state = 11 ? false : true)
  authorization = CarrierAgencyAuthorization.create(
    state: state,
    available: available,
    carrier_agency: carrier_agency,
    policy_type: @policy_type,
    agency: @get_covered
  )
  Fee.create(title: "Service Fee", 
             type: :MISC, 
             per_payment: false,
             amortize: false, 
             amount: @fee_amount, 
             amount_type: :FLAT, 
             enabled: true, 
             assignable: authorization, 
             ownerable: @get_covered) unless @fee_amount.nil?
end
 # MOOSE WARNING: regular service fee??? and should service fee above & commission strat below be changed?

@get_covered.billing_strategies.create!(title: 'Annually', enabled: true, carrier: @carrier, 
                                          policy_type: @policy_type, carrier_code: "Annual",
                                          fees_attributes: [])
@get_covered.commission_strategies.create!(title: 'Get Covered / Deposit Choice Producer Commission', 
                                            carrier: @carrier,
                                            policy_type: @policy_type, 
                                            amount: 5, 
                                            type: 0, 
                                            house_override: 0)



########################################################################
########################## TEST INSURABLES #############################
########################################################################
if @create_test_insurables

@created_communities = []

@addresses = [{
  street_number: '1392',
  street_name: 'Post Oak Dr',
  city: 'Clarkston',
  state: 'GA',
  zip_code: '30021'
]}


building_name_options = ['Estates', 'Gardens', 'Homes', 'Place']
accounts = @carrier.agencies.map{|ag| ag.accounts.to_a }.flatten.map{|acct| { account: acct, assignments: 0 } }
@addresses.each do |addr|
  # set things up
  args = {
    carrier_id: @carrier.id,
    policy_type_id: @policy_type.id,
    state: addr[:state],
    zip_code: addr[:zip_code]
  }
  accounts.sort{|a,b| a[:assignments] <=> b[:assignments] }.each do |account_data|
    account = account_data[:account]
    assigned = false
    if account.agency.offers_policy_type_in_region(args)
      # create community from DC's records
      pad = @community.primary_address
      result = ::Insurable.deposit_choice_address_search(
        address1: pad.combined_street_address,
        address2: pad.street_two.blank? ? nil : pad.street_two,
        city: pad.city,
        state: pad.state,
        zip_code: pad.zip_code
      )
      result = ::Insurable.deposit_choice_create_insurable_from_response(result,
        account: account
      )
      success = (result.class == ::Insurable)
      if success
        assigned = true
      else
        puts "\nCommunity Save Error\n\n"
        pp result
      end
    end    
    if assigned
      account_data[:assignments] += 1
      break
    end
  end
end













end

