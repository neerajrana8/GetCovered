@agency = Agency.find(1)

@master_policies = [
  {
		effective_date: Time.current.to_date - 6.months + iter.days,
		expiration_date: Time.current.to_date + 6.months + iter.days,    
    status: "BOUND",
    auto_renew: true,
    agency: @agency,
    account: @agency.accounts.first,
    policy_type: PolicyType.find(2)
    policy_coverages_attributes: [
      { title: "Liability Coverage", designation: "liability_coverage", limit: rand(700000..1000000).round(-3), deductible: 0 },
      { title: "Expanded Liability Coverage", designation: "expanded_liability", limit: rand(700000..1000000).round(-3), deductible: 0 },
      { title: "Pet Damage", designation: "pet_damage", limit: rand(100000..500000).round(-3), deductible: rand(25000..100000).round(-3) },
      { title: "Loss of Rent", designation: "loss_of_rents", limit: rand(100000..500000).round(-3), deductible: 0 },
      { title: "Tenant Contingent Contents", designation: "tenant_contingent_contents", limit: rand(100000..500000).round(-3), deductible: 0 },
      { title: "Contingent Contents", designation: "contingent_contents", limit: rand(100000..500000).round(-3), deductible: 0 }
    ]
  }
]