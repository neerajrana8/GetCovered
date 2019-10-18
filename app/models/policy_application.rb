##
# =Policy Application Model
# file: +app/models/policy_application.rb+

class PolicyApplication < ApplicationRecord  
  
  # Concerns
  include CarrierQbePolicyApplication, ElasticsearchSearchable
  
  # Active Record Callbacks
  after_initialize :initialize_policy_application
  
  before_validation :set_reference, if: Proc.new { |app| app.reference.nil? }
  
  after_create :set_up_application_answers
  
  belongs_to :carrier
  belongs_to :policy_type
  belongs_to :agency
  belongs_to :account
  belongs_to :billing_strategy
  belongs_to :policy, optional: true
  
  has_many :addresses, as: :addressable, autosave: true
    
  has_many :policy_insurables
  has_many :insurables, through: :policy_insurables, before_add: :check_address
  
  has_many :policy_users
  has_many :users, through: :policy_users
	
	has_many :events, as: :eventable
    
  has_one :primary_policy_user, -> { where(primary: true).take }, 
    class_name: 'PolicyUser'
  has_one :primary_user,
    class_name: 'User',
    through: :primary_policy_user,
    source: :user
    
  has_many :policy_quotes
  has_many :policy_premiums,
    through: :policy_quotes
	    
	has_many :policy_rates
	has_many :insurable_rates,
		through: :policy_rates
    
  has_many :policy_application_answers
  has_many :policy_application_fields,
  	through: :policy_application_answers
	
	validates_presence_of :expiration_date, :effective_date
  validate :date_order, 
    unless: Proc.new { |pol| pol.effective_date.nil? or pol.expiration_date.nil? }	
	
  enum status: { started: 0, in_progress: 1, complete: 2, abandoned: 3, 
	  						 quote_in_progress: 4, quote_failed: 5, quoted: 6, 
	  						 more_required: 7, rejected: 8 }
	
	# PolicyApplication.estimate()
						 	
	def estimate(args = [])
		method = "#{ carrier.integration_designation }_estimate"
		self.send(method, args) if complete? && self.respond_to?(method)
		return false if !complete?
	end
	
	# PolicyApplication.quote()
	# Calls quote method for applicable carrier & service
	# using the naming convention #{ carrier.integration_designation }_quote 
	# if the method exists.	
  
	def quote
		method = "#{ carrier.integration_designation }_quote"
		self.send(method) if complete? && self.respond_to?(method)
		return false if !complete?
	end
	
	# PolicyApplication.primary_insurable
	
	def primary_insurable
		policy_insurable = policy_insurables.where(primary: true).take
		return policy_insurable.insurable.nil? ? nil : policy_insurable.insurable	
	end
  
  # PolicyApplication.available_rates
  
  def available_rates(opts = {})
	  query = {
		  :number_insured => users.count,
		  :interval => 'month'
	  }.merge!(opts)
		return primary_insurable().insurable_rates
															.count > 0 ? primary_insurable().insurable_rates.where(query) : 
																					 primary_insurable().insurable.insurable_rates.where(query)
	end

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :reference, type: :text, analyzer: 'english'
      indexes :external_reference, type: :text, analyzer: 'english'
    end
	end
	
	def check_address(insurable)
		throw :no_address if insurable.primary_address().nil?
	end
  
  private 
  
    def initialize_policy_application
    end
	
    def date_order
      if expiration_date < effective_date
        errors.add(:expiration_date, "expiration date cannot be before effective date.")  
      end  
    end	
    
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
	  
	  def set_up_application_answers
			carrier.policy_application_fields
						 .where(policy_type: policy_type, enabled: true)
						 .each do |field|
							 
				self.policy_application_answers.create!(
					policy_application_field: field
				)
			end  
		end
end
