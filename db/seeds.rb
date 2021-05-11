# Available Options for rails db:seed section=[input]
# command
# woof woof I'm a big crazy hound dog

@opts = ['setup', 'agency', 'account', 'insurable-residential', 
	  		 'insurable-commercial', 'insurable-cambridge', 'user', 
	  		 'policy-residential', 'policy-master', 'policy-commercial',
	  		 'production', 'staging', 'reset', 'elasticsearch', 'pensio', 'branding-profiles',
         'msi', 'msi-production', 'msi-test-addresses', 'msi-regenerate-ircs',
         'deposit-choice']

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

elsif ENV["section"].blank?

  puts "\nNO SECTION SELECTION -- NO SEEDS RUN"
  
elsif !@opts.include?(ENV["section"])

	puts "\nInvalid Section Selection '#{ENV["section"]}'"
	puts "Option availability in order: #{ display_options() }\n"

end
