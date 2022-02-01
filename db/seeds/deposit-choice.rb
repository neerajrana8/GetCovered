require './db/seeds/functions'
require 'faker'
require 'socket'




########################################################################
######################## BASIC CARRIER SETUP ###########################
########################################################################

@dc_id = DepositChoiceService.carrier_id
puts "Initializing carrier ##{@dc_id}..."

@create_test_insurables = ENV['create_test_insurables'] || false
@create_test_policies = ENV['create_test_policies'] || false

@residential_community = InsurableType.find(1)
@residential_unit = InsurableType.find(4)


@carrier = Carrier.where(id: @dc_id).take || Carrier.create!({
  id: DepositChoiceService.carrier_id,
  title: "Deposit Choice",
  integration_designation: "dc",
  syncable: false,
  rateable: true,
  quotable: true,
  bindable: true,
  verifiable: false,
  enabled: true
}.compact)

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

@get_covered = Agency.where(title: "Get Covered").take
@cpt = CarrierPolicyType.where(carrier: @carrier, policy_type: @policy_type).take || CarrierPolicyType.create!({
  carrier: @carrier,
  policy_type: @policy_type,
  application_required: true,
  commission_strategy_attributes: { recipient: @get_covered, percentage: 10 },
  application_fields: [
  ]
})

51.times do |state|
  available = (state == 0 || state == 11 ? false : true)
  cpa = CarrierPolicyTypeAvailability.create(state: state, available: available, carrier_policy_type: @cpt)
end unless CarrierPolicyTypeAvailability.where(carrier_policy_type: @cpt).limit(1).count > 0


########################################################################
########################## GC AGENCY SETUP #############################
########################################################################

puts "  Initializing DC agencies..."

@get_covered = Agency.where(title: "Get Covered").take

carrier_agency = CarrierAgency.where(carrier: @carrier, agency: @get_covered).take
if carrier_agency.nil?
  carrier_agency = ::CarrierAgency.create!(
    carrier: @carrier,
    agency: @get_covered,
    carrier_agency_policy_types_attributes: @carrier.carrier_policy_types.map do |cpt|
      {
        policy_type_id: cpt.policy_type_id
      }
    end
  )
end

@get_covered.billing_strategies.create!(title: 'Annually', enabled: true, carrier: @carrier, 
                                          policy_type: @policy_type, carrier_code: "Annual",
                                          fees_attributes: []) unless @get_covered.billing_strategies.where(title: "Annually", carrier_id: @carrier.id).count > 0



########################################################################
########################## TEST INSURABLES #############################
########################################################################
if @create_test_insurables

puts "  Creating DC test insurables..."

@created_communities = []

@addresses = [
  #  This one apparently no longer works on DC's end
  #{
  #  street_number: '1392',
  #  street_name: 'Post Oak Dr',
  #  city: 'Clarkston',
  #  state: 'GA',
  #  zip_code: '30021'
  #},
  {
    street_number: '123',
    street_name: 'S Pennsylvania St',
    city: 'Denver',
    state: 'CO',
    zip_code: '80209'
  }
]


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
      result = ::Insurable.deposit_choice_address_search(
        address1: "#{addr[:street_number]} #{addr[:street_name]}",
        address2: addr[:street_two] || nil,
        city: addr[:city],
        state: addr[:state],
        zip_code: addr[:zip_code]
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













end # end test insurables



puts "  DC seed success!"
