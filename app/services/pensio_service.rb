# Pensio Service Model
# file: app/models/pensio_choice_service.rb
#

require 'base64'
require 'fileutils'

class PensioService

  def self.carrier_id
    4
  end
  
  def self.carrier
    @pensio ||= Carrier.find(4)
  end
    
end


