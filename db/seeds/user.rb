# User Setup File
# file: db/seeds/user.rb

@units = Insurable.residential_units
@units.each do |unit|
  
  # Create a 66% Occupancy Rate
  occupied_chance = rand(0..100)
  if occupied_chance > 33
    
    @lease = unit.leases.new
    # pp @lease
    
  end
end