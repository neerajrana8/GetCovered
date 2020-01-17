@models = [Account, Address, Agency, Carrier, Claim, 
					 Insurable, Invoice, Lease, PolicyApplication,
					 PolicyQuote, Policy, Profile, Staff, User]
					 
@models.each do |m|
	m.__elasticsearch__.create_index! force: true
	m.import force: true 
end