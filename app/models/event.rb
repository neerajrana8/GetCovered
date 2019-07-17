# =Event Model
#
# file: app/models/event.rb

class Event < ApplicationRecord
  
  # Active Record Callbacks
  after_initialize  :initialize_event
  after_save :display_deets, if: Proc.new { |e| ENV["RAILS_ENV"] == "development" }
  
  belongs_to :eventable, 
    polymorphic: true
                                    
  enum verb: ['get', 'put', 'post', 
              'patch', 'delete', 'options'], 
              _suffix: true 
              
  enum format: ['json', 'xml']
  
  enum interface: ['REST', 'SOAP']
  
  enum status: ['in_progress', 'success', 'error']
  
  validates :request, 
    presence: true,
    if: Proc.new { |ev| ev.format == 'json' || ev.format == 'xml'  }
  
  validates :response, 
    presence: true,
    if: Proc.new { |ev| (ev.format == 'json' || ev.format == 'xml')  && !ev.completed.nil? }
  
  validates_presence_of :process

  private
    
    def initialize_event
      # Blank for now...
    end
    
    def display_deets
	  	puts "#{ id } : #{ process }"  
	  end
end
