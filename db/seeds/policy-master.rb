@agency = Agency.find(1)
@account = @agency.accounts.first

@qbe = Carrier.find(2)

@policy_types = {
  :master => PolicyType.find(2),
  :coverage => PolicyType.find(3)
}

@master_policy = Policy.new(
  effective_date: (Time.current + 1.months).at_beginning_of_month,
  status: "BOUND",
  agency: @agency,
  account: @account,
  carrier: @qbe,
  policy_type: @policy_types[:master]
)

if @master_policy.save!
  @master_policy.build_coverage_options()
  @account.insurables.where(insurable_type_id: 1).each do |insurable|
    @master_policy.insurables << insurable
  end
end

# @agency = Agency.find(1)
#
# @master_policies = [
#   {
# 		effective_date: Time.current.to_date - 6.months,
# 		expiration_date: Time.current.to_date + 6.months,
#     status: "BOUND",
#     auto_renew: true,
#     agency: @agency,
#     account: @agency.accounts.first,
#     policy_type: PolicyType.find(2),
#     carrier: Carrier.find(2),
#     policy_premiums_attributes: [
# 	    { total: 700, enabled: true }
#     ],
#     policy_coverages_attributes: [
#       { title: "Liability Coverage", designation: "liability_coverage", limit: rand(700000..1000000).round(-3), deductible: 0 },
#       { title: "Expanded Liability Coverage", designation: "expanded_liability", limit: rand(700000..1000000).round(-3), deductible: 0 },
#       { title: "Pet Damage", designation: "pet_damage", limit: rand(100000..500000).round(-3), deductible: rand(25000..100000).round(-3) },
#       { title: "Loss of Rent", designation: "loss_of_rents", limit: rand(100000..500000).round(-3), deductible: 0 },
#       { title: "Tenant Contingent Contents", designation: "tenant_contingent_contents", limit: rand(100000..500000).round(-3), deductible: 0 },
#       { title: "Contingent Contents", designation: "contingent_liability_options", limit: rand(100000..500000).round(-3), deductible: 0 },
#       { title: "Landlord Supplemental", designation: "landlord_supplemental", limit: rand(100000..500000).round(-3), deductible: 0 }
#     ]
#   }
# ]
#
# @master_policies.each do |mp|
# 	policy = Policy.new(mp)
# 	if policy.save
# 		puts "YAY!"
# 	else
# 		pp policy.errors
# 	end
# end
