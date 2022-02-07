# FCC Service Model
# file: app/services/fcc_service.rb
#

require 'base64'
require 'fileutils'

class FccService

  include HTTParty
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming
  
  attr_accessor :message_content,
    :errors,
    :request,
    :action

  DICTIONARY = {
    area: {
      process: "fcc_area",
      verb: :get,
      interface: "REST",
      format: "empty",
      raw_endpoint: "https://geo.fcc.gov/api/census/area",
      endpoint: Proc.new{|s| "https://geo.fcc.gov/api/census/area?lat=#{s.message_content[:lat]}&lon=#{s.message_content[:lon]}&format=json" },
      request: nil
    }
  }
  
  
  def initialize
    self.action = nil
    self.errors = nil
  end

  def event_params
    DICTIONARY[self.action].transform_values{|v| v.is_a?(::Proc) ? v.call(self) : v }
  end
  
  def build_request(action_name, **args)
    self.action = action_name
    self.errors = nil
    begin
      self.send("build_#{action_name}", **args)
    rescue ArgumentError => e
      self.errors = { arguments: e.message }
    end
    return self.errors.blank?
  end
  
  def build_area(
    lat:,
    lon:,
    **compilation_args
  )
    # put the request together
    self.action = :area
    self.errors = nil
    self.message_content = {
      lat: lat,
      lon: lon
    }
    return errors.blank?
  end

  def call
    # set up call_data
    call_data = {
      error: false,
      code: 200,
      message: nil,
      response: nil,
      data: nil
    }
    from_dict = DICTIONARY[self.action].transform_values{|v| v.is_a?(::Proc) ? v.call(self) : v }
    # try to call
    begin
      if from_dict[:verb] == :get
        call_data[:response] = HTTParty.get(from_dict[:raw_endpoint],
          query: message_content.transform_keys{|k| k.to_s }
        )
      else
        call_data[:error] = true
        call_data[:code] = 404
        call_data[:message] = "The action '#{self.action}' was not recognized by the FCC service"
        call_data[:response] = nil
      end
    rescue StandardError => e
      call_data = {
        error: true,
        code: 500,
        message: 'Request Timeout',
        response: e
      }
    end
    # handle response
    if call_data[:error]
      puts 'ERROR ERROR ERROR'.red
      pp call_data
    else
      call_data[:data] = call_data[:response].parsed_response
    end
    # scream to the console for the benefit of any watchers
    display_status = call_data[:error] ? 'ERROR' : 'SUCCESS'
    display_status_color = call_data[:error] ? :red : :green
    puts "#{'['.yellow} #{'FCC Service'.blue} #{']'.yellow}#{'['.yellow} #{display_status.colorize(display_status_color)} #{']'.yellow}: #{action.to_s.blue}"
    # all done
    return call_data
  end

end
