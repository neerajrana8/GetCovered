# =Set Reference Concern
# file: +app/models/concerns/blacklistable.rb+

module SetReference
  extend ActiveSupport::Concern
  
  # Active Record Callbacks
  before_validation :set_reference,
  	if: Proc.new { |model| model.reference.nil? }
  
  private
  
  	def set_reference
	    return_status = false
	    
	    if reference.nil?
	      
	      loop do
	        self.reference = "#{account.call_sign}-#{rand(36**12).to_s(36).upcase}"
	        return_status = true
	        
	        break unless PolicyApplication.exists?(:reference => self.reference)
	      end
	    end
	    
	    return return_status	  		
	  end
  
end