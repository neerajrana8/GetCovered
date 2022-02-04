# =Event Model
#
# file: app/models/event.rb

class Event < ApplicationRecord
  
  # Active Record Callbacks
  after_initialize  :initialize_event
  after_save :display_deets, if: Proc.new { |e| ENV["RAILS_ENV"] == "development" }
  
  belongs_to :eventable, 
    polymorphic: true,
    optional: true
                                    
  enum verb: ['get', 'put', 'post', 
              'patch', 'delete', 'options'], 
              _suffix: true 
              
  enum format: ['json', 'xml', 'empty']
  
  enum interface: ['REST', 'SOAP']
  
  enum status: ['in_progress', 'success', 'error']
  
  # Validations
  
  validates_presence_of :verb, :format, :interface, :status, :process, :endpoint
  
  # These are commented out because I am sick of bugs where events don't exist that turn out to be a result of unexpectedly empty requests/responses:
  #validates :request, 
  #  presence: true,
  #  if: Proc.new { |ev| ev.format == 'json' || ev.format == 'xml'  }
  #validates :response, 
  #  presence: true,
  #  if: Proc.new { |ev| (ev.format == 'json' || ev.format == 'xml')  && !ev.completed.nil? }

	def duration
		return started.nil? || completed.nil? ? nil : (completed - started) * 1000.0
	end

  private
    
    def initialize_event
      # Blank for now...
    end
    
    def display_deets
	  	puts "#{ id } : #{ process }"  
	  end
end
