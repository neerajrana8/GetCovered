if ENV["section"] =~ /setup|agency|account|insurable|user|policy/
  
  puts "Running: #{ENV["section"].titlecase}"
  require Rails.root.join("db/seeds/#{ ENV["section"] }.rb")
  
elsif ENV["section"].nil?
  
  puts "\nNO SECTION SELECTION"
  puts "Option availability in order: setup, agency, account, insurable, user, policy\n"

end