##
# =Policy Quote Model
# file: +app/models/policy_quote.rb+
# frozen_string_literal: true

class PolicyQuote < ApplicationRecord
  # Concerns
  #include CarrierQbeQuote, ElasticsearchSearchable
  include ElasticsearchSearchable


  after_initialize  :initialize_policy_quote
  
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
	
	has_one :policy_premium
	
  enum status: { AWAITING_ESTIMATE: 0, ESTIMATED: 1, QUOTED: 2, QUOTE_FAILED: 3, ABANDONED: 4 }
	
	def mark_successful
  	policy_application.update status: 'quoted' if update status: 'QUOTED'
  end
  
  def mark_failure
  	policy_application.update status: 'quote_failed' if update status: 'QUOTE_FAILED'
  end
  
  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :reference, type: :text, analyzer: 'english'
      indexes :external_reference, type: :text, analyzer: 'english'
    end
  end
  
  private
    def initialize_policy_quote
      # self.status ||= :AWAITING_ESTIMATE
    end
    
    def set_status_updated_on
	    self.status_updated_on = Time.now
	  end
    
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
