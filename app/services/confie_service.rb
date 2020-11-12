# Confie Service Model
# file: app/services/confie_service.rb
#

require 'base64'
require 'fileutils'

class ConfieService

  def self.agency_id
    # MOOSE WARNING: do this
  end
  
  include HTTParty
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming
  
  attr_accessor :compiled_rxml,
    :errors,
    :request,
    :action,
    :rxml,
    :coverage_codes
  
  def initialize
    self.action = nil
    self.errors = nil
  end
  
  def event_params
    {
      verb: 'post',
      format: 'xml',
      interface: 'REST',
      endpoint: self.endpoint_for(self.action),
      process: "confie_#{self.action}"
    }
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
  
  def endpoint_for(which_call) # MOOSE WARNING: fix it up
    Rails.application.credentials.confie[:uri][ENV['RAILS_ENV'].to_sym] + "/#{which_call.to_s.camelize}"
  end
  
  def call
    # try to call
    call_data = {
      error: false,
      code: 200,
      message: nil,
      response: nil,
      data: nil
    }
    begin
      
      call_data[:response] = HTTParty.post(endpoint_for(self.action),
        body: compiled_rxml,
        headers: {
          'Content-Type' => 'text/xml'
        },
        ssl_version: :TLSv1_2
      )
    rescue StandardError => e
      call_data = {
        error: true,
        code: 500,
        message: 'Request Timeout',
        response: e
      }
      puts "\nERROR\n"
      #ActionMailer::Base.mail(from: 'info@getcoveredinsurance.com', to: 'dev@getcoveredllc.com', subject: "Confie #{ action } error", body: call_data.to_json).deliver
    end
    # handle response
    if call_data[:error]
      puts 'ERROR ERROR ERROR'.red
      pp call_data
    else
      call_data[:data] = call_data[:response].parsed_response
      #case call_data[:data].dig("MSIACORD", "InsuranceSvcRs", "MsgStatus", "MsgStatusCd")
      #  when 'SUCCESS'
      #    # it worked! huzzah!
      #  when 'ERROR'
      #    call_data[:error] = true
      #    call_data[:message] = "Request failed externally"
      #    call_data[:external_message] = call_data[:data].dig("MSIACORD", "InsuranceSvcRs", "MsgStatus", "MsgStatusDesc").to_s
      #    call_data[:extended_external_message] = [call_data[:data].dig("MSIACORD", "InsuranceSvcRs", "MsgStatus", "ExtendedStatus")].flatten.compact
      #      .map{|el| "#{el["ExtendedStatusCd"]}: #{el["ExtendedStatusDesc"]}" }.join("\n")
      #    call_data[:code] = 409
      #  when nil
      #    call_data[:error] = true
      #    call_data[:message] = "Request failed externally"
      #    call_data[:external_message] = "No status message received"
      #    call_data[:code] = 409
      #end
    end
    # scream to the console for the benefit of any watchers
    display_status = call_data[:error] ? 'ERROR' : 'SUCCESS'
    display_status_color = call_data[:error] ? :red : :green
    puts "#{'['.yellow} #{'Confie Service'.blue} #{']'.yellow}#{'['.yellow} #{display_status.colorize(display_status_color)} #{']'.yellow}: #{action.to_s.blue}"
    # all done
    return call_data
  end
  
  

  
  
  
  
  
  
  
  
  
  
private

    def arrayify(val, nil_as_object: false)
      val.class == ::Array ? val : val.nil? && !nil_as_object ? [] : [val]
    end

    def get_auth_json
      #{
      #  SignonRq: {
      #    SignonPswd: {
      #      CustId: {
      #        CustLoginId: Rails.application.credentials.msi[:un][ENV['RAILS_ENV'].to_sym]
      #      },
      #      CustPswd: {
      #        Pswd: Rails.application.credentials.msi[:pw][ENV['RAILS_ENV'].to_sym]
      #      }
      #    }
      #  }
      #}
    end
    
    def json_to_xml(obj, abbreviate_nils: true, closeless: false,  indent: nil, line_breaks: false, internal: false)
      # dynamic default parameters
      line_breaks = true unless indent.nil?
      indent = "" if line_breaks && indent.nil?
      # go wild
      prop_string = ""
      child_string = ""
      case obj
        when ::Hash
          # handle properties to pass back up to our caller
          if obj.has_key?(:'')
            prop_string = obj[:''].blank? ? "" : obj[:''].class == ::String ? obj[:''] :
              obj[:''].map{|k,v| "#{k}=\"#{v.to_s.gsub('"', '&quot;').gsub('&', '&amp;').gsub('<', '&lt;')}\"" }.join(" ")
            prop_string = " #{prop_string}" unless prop_string.blank?
            obj = obj.select{|k,v| k != :'' }
          end
          # convert ourselves into an xml string
          child_string = obj.map do |k,v|
            # induce recursion and set line break settings
            subxml_result = json_to_xml(v, abbreviate_nils: abbreviate_nils, indent: indent.nil? ? nil : indent + "  ", internal: true)
            subxml_result = [subxml_result] unless subxml_result.class == ::Array
            subxml_result.map do |subxml|
              line_mode = subxml.nil? ? :cancel : !line_breaks ? :none : (subxml[:child_string].nil? || (subxml[:child_string].index("\n").nil? && subxml[:child_string].length < 64)) ? :inline : :block
              # return our fancy little text block
              case line_mode
                when :none, :inline
                  "<#{k}#{subxml[:prop_string]}" + ((abbreviate_nils && subxml[:child_string].nil?) ? "/>"
                    : (">#{subxml[:child_string].to_s}" + (closeless ? "" : "</#{k}>")))
                when :block
                  "<#{k}#{subxml[:prop_string]}" + ((abbreviate_nils && subxml[:child_string].nil?) ? "/>"
                    : (">\n#{indent}  #{subxml[:child_string].to_s}" + (closeless ? "" : "\n#{indent}</#{k}>")))
                when :cancel
                  nil
              end
            end
          end.flatten.compact.join(line_breaks ? "\n#{indent}" : "")
        when ::Array
          return obj.map{|v| json_to_xml(v, abbreviate_nils: abbreviate_nils, indent: indent, internal: true) }
        when ::NilClass
          child_string = nil
        else
          child_string = obj.to_s.gsub("<", "&lt;").gsub("<", "&gt;").gsub("&", "&amp;").split("\n").join("#{indent}\n")
      end
      internal ? {
        prop_string: prop_string,
        child_string: child_string
      } : child_string
    end
  
    def compile_xml(obj, line_breaks: false, **other_args)
      #"<?xml version=\"1.0\" encoding=\"UTF-8\"?>#{line_breaks ? "\n" : ""}" + json_to_xml({
      #  MSIACORD: {
      #    '': {
      #      'xmlns:xsd': 'http://www.w3.org/2001/XMLSchema',
      #      'xmlns:xsi': 'http://www.w3.org/2001/XMLSchema-instance'
      #    }
      #  }.merge(get_auth_json).merge(obj)
      #},
      #  line_breaks: line_breaks,
      #  **other_args
      #)
    end
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
end


