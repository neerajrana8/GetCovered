@opts = ['setup', 'agency', 'account', 'insurable-residential', 
	  		 'insurable-commercial', 'insurable-cambridge', 'user', 
	  		 'policy-residential', 'policy-master', 'policy-commercial', 
	  		 'production', 'staging', 'reset', 'elasticsearch', 'pensio',
         'msi', 'msi-test-addresses', 'msi-regenerate-ircs']

def display_options()
	@string = ""
	@opts.each_with_index do |o, i|
		@string += o
		@string += ", " unless @opts.length - 1 == i	
	end
	return @string
end

if @opts.include?(ENV["section"])
	 
  puts "Running: #{ENV["section"].titlecase}"
  require Rails.root.join("db/seeds/#{ ENV["section"] }.rb")

elsif !@opts.include?(ENV["section"])

	puts "\nInvalid Section Selection"
	puts "Option availability in order: #{ display_options() }\n"
  
elsif ENV["section"].nil?
  
  puts "\nNO SECTION SELECTION"
  puts "Option availability in order: \n"

end
