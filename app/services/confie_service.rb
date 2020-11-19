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
  
  def endpoint_for(which_call) # MOOSE WARNING: apparently the endpoint is constant
    Rails.application.credentials.confie[:uri][ENV['RAILS_ENV'].to_sym]
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
          'Content-Type' => 'text/xml',
          'SOAPAction' => "http://appone.onesystemsinc.com/services/IInsuranceSubmissionService/SubmitPolicy"
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
  
  def build_lead_info(
    policy_application:,
    lob_override: nil,
    **compilation_args
  )
    # put the request together
    self.action = :lead_info
    self.errors = nil
    lobcd = get_lobcd_for_policy_type(policy_application.policy_type_id) || lob_override
    if lobcd.nil?
      self.errors = ["Confie does not support policy type '#{policy.policy_type.title}'"]
    end
    self.compiled_rxml = compile_xml({
      "com.a1_LeadInfo": {
        RqUID: get_unique_identifier,
        TransactionRequestDt: Time.current.to_date.to_s,
        LOBCd: lobcd[0],
        LOBSubCd: lobcd[1],
        InsuredOrPrincipal: policy_application.policy_users.map do |pu|
          get_insured_or_principal_for(pu.user, pu.primary ? code_for_primary_insured : code_for_additional_insured)
        end
      }
    }, **compilation_args)
    return errors.blank?
  end
  
  def build_online_policy_sale(
    policy:,
    **compilation_args
  )
    # we need:
    #   the LOBCd and LOBSubCd
    #   the InsuredOrPrincipalRoleCd for primary insured & additional insured & additional interest
    
    # put the request together
    self.action = :online_policy_sale
    self.errors = nil
    lobcd = get_lobcd_for_policy_type(policy.policy_type_id)
    if lobcd.nil?
      self.errors = ["Confie does not support policy type '#{policy.policy_type.title}'"]
    end
    first_invoice = policy.invoices.order("due_date asc").limit(1).take
    self.compiled_rxml = compile_xml({
      "com.a1_PolicyQuoteInqRq": {
        RqUID: get_unique_identifier,
        TransactionRequestDt: Time.current.to_date.to_s,
        LOBCd: lobcd[0],
        LOBSubCd: lobcd[1],
        InsuredOrPrincipal: (
          policy.policy_users.map do |pu|
            get_insured_or_principal_for(pu.user, pu.primary ? code_for_primary_insured : code_for_additional_insured)
          end + (policy.policy_type_id == ::PolicyType::RESIDENTIAL_ID && policy.carrier_id == MsiService.carrier_id && !policy.account.nil? ?
            [get_insured_or_principal_for(policy.account, code_for_additional_interest)] # MOOSE WARNING: is policy.account the right place to check? should we check for preferred_ho4 status first?
            : []
          )
        ),
        "com.a1_Policy": {
          # no NAICCd, whatever that is
          ContractTerm: {
            EffectiveDt: policy.effective_date.to_s,
            ExpirationDt: policy.expiration_date.to_s
            # MOOSE WARNING: DurationPeriod???
          },
          LanguageCd: "EN",
          PolicyNumber: policy.policy_number,
          CurrentTermAmt: {
            Amt: (first_invoice.total.to_d / 100.to_d).to_s
          },
          FullTermAmt: {
            Amt: (policy.policy_quotes.accepted.order("created_at desc").limit(1).take.policy_premium.total / 100.to_d).to_s
          },
          "com.a1_Payment": payment_info(
            policy.carrier.uses_stripe? ?
              first_invoice.charges.succeeded.take
              : first_invoice.nil? ?
                nil
              : { MethodPaymentCd: "CreditCard", Amount: { Amt: (first_invoice.total.to_d / 100.to_d).to_s } }
          ),
          "com.a1_OnlineSalesFee": {
            Amt: "0.00"
          }
        }.merge(get_a1_policy_codes_for_policy_type(policy_type_id)),
        "com.a1_LeadNotes": "",
        "com.a1_OrganizationCd": "OLBT"
        # leaving out CarrierDocument and InternalDocument...
      }
    }, **compilation_args)
    return errors.blank?
  end
  
  
  
  
  
  
  
  
private

    def code_for_primary_insured
      "PRIMARY"
    end

    def code_for_additional_insured
      "AI"
    end
    
    def code_for_additional_interest
      "AI" # MOOSE WARNING: there's no way this is right
    end

    def payment_info(charge)
      ch = Stripe::Charge.retrieve(charge.stripe_id)
      #cust = Stripe::Customer.retrieve(ch.customer)
      case ch.source.object
        when "card"
          return {
            MethodPaymentCd: "CreditCard",
            Amount:  { Amt: (ch.amount.to_d / 100.to_d).to_s }, # don't know what a CurCd is, says it's optional
            "com.a1_CreditCardInfo": {
              # no credit card numbers for you, confie
              "com.a1_CardHolder": { # MOOSE WARNING: stripe doesn't seem to have credit card name info, so pulling this from user right now
                FirstName: charge.invoice.payer.profile.first_name,
                LastName: charge.invoice.payer.profile.last_name
              },
              BillingAddress: address_from_stripe_source(ch.source)
            }
          }
      end
      return nil
    end
    
    def address_from_stripe_source(source)
      if source.address_city && source.address_line1 && source.address_state && source.address_zip
        {
          AddrTypeCd: "BillingAddress",
          # docs have "Street"... what the heck
          Addr1: source.address_line1,
          Addr2: source.address_line2.blank? ? nil : source.address_line2,
          City: source.address_city,
          StateProvCd: source.address_state, # MOOSE WARNING: comes as code right???
          PostalCode: source.address_zip
        }.compact
      end
      return nil
    end

    def get_insured_or_principal_for(obj, rolecd)
      case obj
        when ::User
          return {
            # Optional: "com.a1_ExternalId":  "#{get_unique_identifier}", # MOOSE WARNING: using auth instead of user-#{obj.id}",
            GeneralPartyInfo:     obj.get_confie_general_party_info,
            InsuredOrPrincipalInfo: {
              InsuredOrPrincipalRoleCd: rolecd,
              PersonInfo: {
                BirthDt: obj.profile.birth_date&.to_s,
                GenderCd: {"male" => "M", "female" => "F", "unspecified" => "U", "other" => "U" }[obj.profile.gender]
                # no further info for you, greedy confie
              }
            }
          }
        when ::Account
          return {
            # Optional: "com.a1_ExternalId":  "#{get_unique_identifier}", # MOOSE WARNING: using auth instead of "account-#{obj.id}",
            GeneralPartyInfo:     obj.get_confie_general_party_info,
            InsuredOrPrincipalInfo: {
              InsuredOrPrincipalRoleCd: rolecd,
              PersonInfo: nil
            }
          }
      end
      return nil
    end

    def get_a1_policy_codes_for_policy_type(policy_type_id)
      case policy_type_id
        when ::PolicyType::RENT_GUARANTEE_ID        
          return {
            "com.a1_CarrierCd": "RE",
            "com.a1_ProgramCd": "NGU"
          }
        when ::PolicyType::RESIDENTIAL_ID        
          return {
            "com.a1_CarrierCd": "GC",
            "com.a1_ProgramCd": "REN"
          }
      end
      return {}
    end

    # returns [lobcd, lobsubcd] or nil if none
    def get_lobcd_for_policy_type(policy_type_id)
      case policy_type_id
        when ::PolicyType::RENT_GUARANTEE_ID
          return ["HOME", "OTP"]
        when ::PolicyType::RESIDENTIAL_ID
          return ["HOME", "OTP"]
      end
      return nil
    end

    def get_unique_identifier
      "#{Time.current.to_i.to_s}-#{rand(2**32)}"
    end

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
      xml_data = json_to_xml({
        ACORD: obj
      },
        line_breaks: line_breaks,
        **other_args
      )
      apply_soap_wrapper(xml_data, line_breaks: line_breaks)
    end
    
    def apply_soap_wrapper(some_xml, line_breaks: true)
      json_to_xml({
        "s:Envelope": {
          '': {
            'xmlns:s': "http://schemas.xmlsoap.org/soap/envelope/"
          },
          "s:Body": {
            "SubmitPolicy": {
              '': {
                'xmlns': "http://appone.onesystemsinc.com/services"
              },
              "request": {
                '': {
                  'xmlns:a': "http://appone.onesystemsinc.com/services/messages",
                  'xmlns:i': "http://www.w3.org/2001/XMLSchema-instance"
                },
                'a:AuthenticationKey': Rails.application.credentials.confie[:auth][ENV['RAILS_ENV'].to_sym].to_s,
                'a:Payload': some_xml.encode(xml: :text)
              }
            }
          }
        }
      }, line_breaks: line_breaks)
    end
    
    
    
    
    
    
    
    
    
    
    
    
    
    
end


