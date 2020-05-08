# Msi Service Model
# file: app/models/msi_service.rb
#

require 'base64'
require 'fileutils'

class MsiService
  
  include HTTParty
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming
  
  attr_accessor :compiled_rxml,
    :errors,
    :request,
    :action,
    :rxml

  #validates :action, 
  #  presence: true,
  #  format: {
  #    with: /GetOrCreateCommunity/QuotePolicy/BindPolicy/GetPolicyDetails/
  #  
  #    with: /getZipCode|PropertyInfo|getRates|getMinPrem|SendPolicyInfo|sendCancellationList|downloadAcordFile/, 
  #    message: 'must be from approved list' 
  #  }
  
  def initialize
    self.action = nil
    self.errors = nil
  end
  
  # Valid action names:
  #   get_or_create_community
  #   quote_final_premium
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
  
  
  ##
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
      
      call_data[:response] = HTTParty.post(Rails.application.credentials.msi[:uri][ENV['RAILS_ENV'].to_sym] + "/#{self.action.to_s.camelize}",
        body: compiled_rxml,
        headers: {
          'Content-Type' => 'text/xml'#MOOSE WARNING: doc example in crazy .net lingo also has: 'Content-Length' => compiled_rxml.length, timeout 15000, cache policy new RequestCachePolicy(RequestCacheLevel.BypassCache)
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
      ActionMailer::Base.mail(from: 'info@getcoveredinsurance.com', to: 'dev@getcoveredllc.com', subject: "MSI #{ action } error", body: call_data.to_json).deliver
    end
    # handle response
    if call_data[:error]
      puts 'ERROR ERROR ERROR'.red
      pp call_data
    else
      call_data[:data] = call_data[:response].parsed_response
      #xml_doc = Nokogiri::XML(call_data[:data])
      
    end
    # scream to the console for the benefit of any watchers
    display_status = call_data[:error] ? 'ERROR' : 'SUCCESS'
    display_status_color = call_data[:error] ? :red : :green
    puts "#{'['.yellow} #{'MSI Service'.blue} #{']'.yellow}#{'['.yellow} #{display_status.colorize(display_status_color)} #{']'.yellow}: #{action.to_s.blue}"
    # all done
    return call_data
  end
=begin
      ##### QBE reference code #####
      
      if call_data[:error]
        
        puts 'ERROR ERROR ERROR'.red
        pp call_data
        
      else
        call_data[:data] = call_data[:response].parsed_response['Envelope']['Body']['processRenterRequestResponse']['xmlOutput']
        xml_doc = Nokogiri::XML(call_data[:data])
        result = nil
        
        if action == 'SendPolicyInfo'
          result = xml_doc.css('MsgStatusCd').children.to_s
          
          unless %w[SUCCESS WARNING].include?(result)
            call_data[:error] = true
            call_data[:message] = 'Request Failed Externally'
            call_data[:code] = 409
          end
        else
          result = xml_doc.css('//result').attr('status').value
          
          if result != 'pass'
            call_data[:error] = true
            call_data[:message] = 'Request Failed Externally'
            call_data[:code] = 409
          end
        end
        
      end
      
      display_status = call_data[:error] ? 'ERROR' : 'SUCCESS'
      display_status_color = call_data[:error] ? :red : :green
      puts "#{'['.yellow} #{'QBE Service'.blue} #{']'.yellow}#{'['.yellow} #{display_status.colorize(display_status_color)} #{']'.yellow}: #{action.to_s.blue}"
      
      call_data
      
      #### end QBE reference code #########
=end
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  def build_get_or_create_community(
      effective_date:,
      community_name:, number_of_units:, sales_rep_id:, property_manager_name:, years_professionally_managed:, year_built:, gated:,
      address_line_one:, city:, state:, zip:,
      **compilation_args
  )
    self.action = :get_or_create_community
    self.errors = nil
    self.compiled_rxml = compile_xml({
      InsuranceSvcRq: {
        RenterPolicyQuoteInqRq: {
          MSI_CommunityInfo: {
            MSI_CommunityName:                community_name,
            MSI_CommunityYearsProfManaged:    years_professionally_managed.nil? ? 6 : years_professionally_managed,
            MSI_PropertyManagerName:          property_manager_name,
            MSI_NumberOfUnits:                number_of_units,
            MSI_CommunitySalesRepID:          sales_rep_id,
            MSI_CommunityYearBuilt:           year_built,
            MSI_CommunityIsGated:             gated.nil? ? true : gated,
            Addr: {
              Addr1:                          address_line_one,
              Addr2:                          nil,
              City:                           city,
              StateProvCd:                    state,
              PostalCode:                     zip
            }
          },
          PersPolicy: {
            ContractTerm: {
              EffectiveDt:                    effective_date.strftime("%F")
            }
          },
          HomeLineBusiness: {
            Dwell: {
              :'' => { LocationRef: 0, id: "Dwell1" },
              PolicyTypeCd: 'H04'
            }
          }
        }
      }
    }, **compilation_args)
    return errors.blank?
  end
  
  def build_quote_final_premium(
    community_id:, effective_date:,
    **compilation_args
  )
    self.action = :quote_final_premium
    self.errors = nil
    compiled_rxml = compile_xml({
      InsuranceSvcRq: {
        RenterPolicyQuoteInqRq: {
          # insured or principals
          Location: {
            '': { id: '0' },
            Addr: {
              MSI_CommunityID:                  community_id
            },
            PersPolicy: {
              ContractTerm: {
                EffectiveDt:                    effective_date.strftime("%D")
              }
            },
            HomeLineBusiness: {
              Dwell: {
                '': { LocationRef: '0', id: 'Dwell1' },
                PolicyTypeCd: 'H04'
              }
            }
            #coverages
          }
        }
      }
    }, **compilation_args)
    return errors.blank?
  end
  
  
private

    def get_auth_json
      {
        SignonRq: {
          SignonPswd: {
            CustId: {
              CustLoginId: Rails.application.credentials.msi[:un][ENV['RAILS_ENV'].to_sym]
            },
            CustPswd: {
              Pswd: Rails.application.credentials.msi[:pw][ENV['RAILS_ENV'].to_sym]
            }
          }
        }
      }
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
            subxml = json_to_xml(v, abbreviate_nils: abbreviate_nils, indent: indent.nil? ? nil : indent + "  ", internal: true)
            line_mode = !line_breaks ? :none : (subxml[:child_string].nil? || (subxml[:child_string].index("\n").nil? && subxml[:child_string].length < 64)) ? :inline : :block
            # return our fancy little text block
            case line_mode
              when :none, :inline
                "<#{k}#{subxml[:prop_string]}" + ((abbreviate_nils && subxml[:child_string].nil?) ? "/>"
                  : (">#{subxml[:child_string].to_s}" + (closeless ? "" : "</#{k}>")))
              when :block
                "<#{k}#{subxml[:prop_string]}" + ((abbreviate_nils && subxml[:child_string].nil?) ? "/>"
                  : (">\n#{indent}  #{subxml[:child_string].to_s}" + (closeless ? "" : "\n#{indent}</#{k}>")))
            end
          end.join(line_breaks ? "\n#{indent}" : "")
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
      compiled_rxml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>#{line_breaks ? "\n" : ""}" + json_to_xml({
        MSIACORD: {
          '': {
            'xmlns:xsd': 'http://www.w3.org/2001/XMLSchema',
            'xmlns:xsi': 'http://www.w3.org/2001/XMLSchema-instance'
          }
        }.merge(get_auth_json).merge(obj)
      },
        line_breaks: line_breaks
      )
    end
end


