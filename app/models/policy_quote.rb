# frozen_string_literal: true

class PolicyQuote < ApplicationRecord
  # Concerns
  #include CarrierQbeQuote, ElasticsearchSearchable
  include ElasticsearchSearchable
  
  before_validation :set_reference,
  	if: Proc.new { |quote| quote.reference.nil? }

  belongs_to :policy_application, optional: true
  
  belongs_to :agency, optional: true
  belongs_to :account, optional: true
  belongs_to :policy, optional: true
	
	has_many :events,
	    as: :eventable
	    
	has_many :policy_rates
	has_many :insurable_rates,
		through: :policy_rates

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :reference, type: :text, analyzer: 'english'
      indexes :external_reference, type: :text, analyzer: 'english'
    end
  end
  
  private
    
    def set_reference
	    return_status = false
	    
	    if reference.nil?
	      
	      loop do
	        self.reference = "#{account.call_sign}-#{rand(36**12).to_s(36).upcase}"
	        return_status = true
	        
	        break unless PolicyQuote.exists?(:reference => self.reference)
	      end
	    end
	    
	    return return_status	  	  
	  end
  
end
