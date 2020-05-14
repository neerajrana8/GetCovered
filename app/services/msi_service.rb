# Msi Service Model
# file: app/models/msi_service.rb
#

require 'base64'
require 'fileutils'

class MsiService

  @@coverage_codes = {
    AllOtherPeril:                                { code: 1, limit: true },
    Theft:                                        { code: 2, limit: false },
    Hurricane:                                    { code: 3, limit: false },
    Wind:                                         { code: 4, limit: false },
    WindHail:                                     { code: 5, limit: false },
    CoverageA:                                    { code: 1001, limit: false },
    CoverageB:                                    { code: 1002, limit: false },
    CoverageC:                                    { code: 1003, limit: true },
    CoverageD:                                    { code: 1004, limit: true },
    CoverageE:                                    { code: 1005, limit: true },
    CoverageF:                                    { code: 1006, limit: true },
    PetDamage:                                    { code: 1007, limit: false },
    WaterBackup:                                  { code: 1008, limit: false },
    TenantsPlusPackage:                           { code: 1009, limit: false },
    ReplacementCost_UnscheduledPersonalProperty:  { code: 1010, limit: false },
    ScheduledPersonalProperty:                    { code: 1011, limit: false },
    ScheduledPersonalProperty_Jewelry:            { code: 1012, limit: true },
    ScheduledPersonalProperty_Furs:               { code: 1013, limit: true },
    ScheduledPersonalProperty_Silverware:         { code: 1014, limit: true },
    ScheduledPersonalProperty_FineArts:           { code: 1015, limit: true },
    ScheduledPersonalProperty_Cameras:            { code: 1016, limit: true },
    ScheduledPersonalProperty_MusicalEquipment:   { code: 1017, limit: true },
    ScheduledPersonalProperty_GolfEquipment:      { code: 1018, limit: true },
    ScheduledPersonalProperty_StampCollections:   { code: 1019, limit: true },
    ScheduledPersonalProperty_MensJewelry:        { code: 1020, limit: true },
    ScheduledPersonalProperty_WomensJewelry:      { code: 1021, limit: true },
    IncreasedPropertyLimits:                      { code: 1040, limit: true },
    IncreasedPropertyLimits_JewelryWatchesFurs:   { code: 1041, limit: false },
    IncreasedPropertyLimits_SilverwareGoldwarePewterware:
                                                  { code: 1042, limit: false },
    IncreasedPropertyLimits_JewelryWatches:       { code: 1043, limit: false },
    AnimalLiability:                              { code: 1060, limit: true },
    Earthquake:                                   { code: 1061, limit: false },
    WorkersCompensation:                          { code: 1062, limit: false },
    HomeDayCare:                                  { code: 1063, limit: false },
    InvoluntaryUnemployment:                      { code: 1064, limit: false },
    IdentityFraud:                                { code: 1065, limit: false },
    FireDepartmentService:                        { code: 1066, limit: false },
    SinkHole:                                     { code: 1067, limit: false },
    WindHailExclusion:                            { code: 1068, limit: false },
    OrdinanceOrLaw:                               { code: 1070, limit: false },
    LossAssessment:                               { code: 1071, limit: true },
    RefrigeratedProperty:                         { code: 1072, limit: false },
    RentalIncome:                                 { code: 1073, limit: false },
    FungiContents:                                { code: 1074, limit: false },
    ForcedEntryTheft:                             { code: 1076, limit: false },
    FungiLiability:                               { code: 1078, limit: false },
    SelfStorageBuyBack:                           { code: 1081, limit: false }
  }
  
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
  #   final_premium
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
          'Content-Type' => 'text/xml'
        },
        ssl_version: :TLSv1_2
      )
      #MOOSE WARNING: doc example in crazy .net lingo also has: 'Content-Length' => compiled_rxml.length, timeout 15000, cache policy new RequestCachePolicy(RequestCacheLevel.BypassCache)
          
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
      call_data[:data] = call_data[:response].parsed_response # WARNING: if staging server doesn't parse to json, we might need this and its fellows: xml_doc = Nokogiri::XML(call_data[:data])
      case call_data[:data].dig("MSIACORD", "InsuranceSvcRs", "MsgStatus", "MsgStatusCd")
        when 'SUCCESS'
          # it worked! huzzah!
        when 'ERROR'
          call_data[:error] = true
          call_data[:message] = "Request failed externally"
          call_data[:code] = 409
        when nil
          call_data[:error] = true
          call_data[:message] = "Request failed externally"
          call_data[:code] = 409
      end
      
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
      community_name:, number_of_units:, property_manager_name:, years_professionally_managed:, year_built:, gated:,
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
            MSI_CommunitySalesRepID:          Rails.application.credentials.msi[:csr][ENV["RAILS_ENV"].to_sym].to_s,
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

  def build_final_premium(
     effective_date:, additional_insured_count:, additional_interest_count:,
     community_id:, #address_line_one:, city:, state:, zip:,
     coverage_DEBUG:, # MOOSE WARNING: for debug!
    **compilation_args
  )
    self.action = :final_premium
    self.errors = nil
    # arguing with arguments
    if additional_insured_count > 7
      return ['Additional insured count cannot exceed 7']
    elsif additional_interest_count > 2
      return ['Additional interest count cannot exceed 2']
    end
    # go go go
    self.compiled_rxml = compile_xml({
      InsuranceSvcRq: {
        RenterPolicyQuoteInqRq: {
          Location: {
            '': { id: '0' },
            Addr: {
              MSI_CommunityID:                  community_id
            }
          },
          PersPolicy: {
            ContractTerm: {
              EffectiveDt:                    effective_date.strftime("%D")
            }
          },
          HomeLineBusiness: {
            Dwell: {
              :'' => { LocationRef: 0, id: "Dwell1" },
              PolicyTypeCd: 'H04'
            },
            Coverage: coverage_DEBUG
          },
          InsuredOrPrincipal: [
            InsuredOrPrincipalInfo: {
              InsuredOrPrincipalRoleCd: "PRIMARYNAMEDINSURED"
            }
          ] + (0...additional_insured_count).map{|n| { InsuredOrPrincipalInfo: { InsuredOrPrincipalRoleCd: "OTHERNAMEDINSURED" } } } +
              (0...additional_interest_count).map{|n| { InsuredOrPrincipalInfo: { InsuredOrPrincipalRoleCd: "ADDITIONALINTEREST" } } }
        }
      }
    }, **compilation_args)
    return errors.blank?
  end
  
  def build_bind_policy(
     effective_date:, additional_insured_count:, additional_interest_count:,
     payment_plan:, installment_day:,
     community_id:, #address_line_one:, city:, state:, zip:,
     payment_merchant_id:, payment_processor:, payment_method:, payment_info:, payment_other_id:,
     primary_insured:, additional_insured:, additional_interest:,
     coverage_DEBUG:, # MOOSE WARNING: for debug!
    **compilation_args
  )
    self.action = :final_premium
    self.errors = nil
    # arguing with arguments
    if additional_insured.count > 7
      return ['Additional insured count cannot exceed 7']
    elsif additional_interest.count > 2
      return ['Additional interest count cannot exceed 2']
    end
    # go go go
    self.compiled_rxml = compile_xml({
      InsuranceSvcRq: {
        RenterPolicyQuoteInqRq: {
          Location: {
            '': { id: '0' },
            Addr: {
              MSI_CommunityID:                community_id
            }
          },
          PersPolicy: {
            ContractTerm: {
              EffectiveDt:                    effective_date.strftime("%D")
            },
            PaymentPlan: {
              PaymentPlanCd:                  payment_plan,
              InstallmentDayofMonth:          installment_day
            },
            PaymentMethod: {
              MSI_PaymentMerchantID:          payment_merchant_id,
              MSI_PaymentProcessor:           payment_processor,
              MethodPaymentCd:                payment_method
            }.merge(                          payment_info)
          },
          HomeLineBusiness: {
            Dwell: {
              :'' => { LocationRef: 0, id: "Dwell1" },
              PolicyTypeCd: 'H04'
            },
            Coverage: coverage_DEBUG
          },
          InsuredOrPrincipal: [
            {
              ItemIdInfo: {
                OtherIdentifier: {
                  OtherTypeCd: "CustProfileId",
                  OtherId:                    payment_other_id
                },
                InsuredOrPrincipalInfo: {
                  InsuredOrPrincipalRoleCd: "PRIMARYNAMEDINSURED"
                },
                GeneralPartyInfo:             primary_insured
              }
            }
          ] + additional_insured.map do |ai|
            {
              InsuredOrPrincipalInfo: {
                InsuredOrPrincipalRoleCd: "OTHERNAMEDINSURED"
              },
              GeneralPartyInfo:               ai
            }
          end + additional_interest.map do |ai|
            {
              InsuredOrPrincipalInfo: {
                InsuredOrPrincipalRoleCd: "ADDITIONALINTEREST"
              },
              GeneralPartyInfo:               ai
            }
          end
        }
      }
    }, **compilation_args)
    return errors.blank?
  end
  
  def build_policy_details(
    policy_number:,
    **compilation_args
  )
    self.action = :policy_details
    self.errors = nil
    # w000t
    self.compiled_rxml = compile_xml({
      InsuranceSvcRq: {
        RenterPolicyQuoteInqRq: {
          MSI_PolicySearch: {
            PolicyNumber:                     policy_number
          }
        }
      }
    }, **compilation_args)
    return errors.blank?
  end
  
  def build_policy_download(
    start_datetime:, end_datetime:,
    ignore_start_time: false, ignore_end_time: false, ignore_times: false,
    **compilation_args
  )
    self.action = :policy_download
    self.errors = nil
    # param magic
    if ignore_times
      ignore_start_time = true
      ignore_end_time = true
    end
    start_time_code = (ignore_start_time ? "%F" : "%F %T")
    end_time_code = (ignore_end_time ? "%F" : "%F %T")
    # w00t!!!
    self.compiled_rxml = compile_xml({
      InsuranceSvcRq: {
        RenterPolicyQuoteInqRq: {
          TransactionStartDate:               start_datetime.strftime(start_time_code),
          TransactionEndDate:                 end_datetime.strftime(end_time_code)
        }
      }
    }, **compilation_args)
    return errors.blank?
  end
  
  def build_claims_download(
    start_datetime:, end_datetime:,
    ignore_start_time: false, ignore_end_time: false, ignore_times: false,
    **compilation_args
  )
    self.action = :claims_download
    self.errors = nil
    # param magic
    if ignore_times
      ignore_start_time = true
      ignore_end_time = true
    end
    start_time_code = (ignore_start_time ? "%F 00:00:00" : "%F %T")
    end_time_code = (ignore_end_time ? "%F 23:59:59" : "%F %T")
    # yepperdoodles!!!
    self.compiled_rxml = compile_xml({
      InsuranceSvcRq: {
        RenterPolicyQuoteInqRq: {
          TransactionStartDate:               start_datetime.strftime(start_time_code),
          TransactionEndDate:                 end_datetime.strftime(end_time_code)
        }
      }
    }, **compilation_args)
    return errors.blank?
  end
  
  def build_web_api_credit_card_authorization_request(
    property_state:, underwriter:,
    **compilation_args
  )
    self.action = :web_api_credit_card_authorization_request
    self.errors = nil
    # do it bro, I dare you
    self.compiled_rxml = compile_xml({
      InsuranceSvcRq: {
        RenterPolicyQuoteInqRq: {
          Location: {
            Addr: {
              StateProvCd:                    state
            }
          },
          PersPolicy: {
            CompanyProductCd:                 underwriter
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
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>#{line_breaks ? "\n" : ""}" + json_to_xml({
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


