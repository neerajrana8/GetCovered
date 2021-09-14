# Confie Service Model
# file: app/services/confie_service.rb
#

require 'base64'
require 'fileutils'

class ConfieService

  def self.agency_id
    @agency ||= ::Agency.where(integration_designation: "confie").take
    @agency_id ||= @agency&.id
  end

  def self.agency
    @agency ||= ::Agency.where(integration_designation: "confie").take
  end

  def self.create_confie_lead(application)
    return "Policy application is for a non-Confie agency" unless application.agency_id == ::ConfieService.agency_id
    cs = ::ConfieService.new
    return "Failed to build create_lead request" unless (cs.build_request(:create_lead,
      user: application.primary_user,
      lead_id: application.id,
      #address: application.primary_address # leaving disabled for now; will default to user.address instead
      line_breaks: true
    ) rescue false)
    event = application.events.new(cs.event_params)
    event.started = Time.now
    result = cs.call
    event.completed = Time.now
    event.request = result[:response].request.raw_body
    event.response = result[:response].response.body
    event.status = result[:error] ? 'error' : 'success'
    event.save
    return "Request resulted in error" if result[:error]
    media_code = (result[:response].parsed_response.dig("data", "media_code") rescue nil)
    unless media_code.blank?
      application.update(tagging_data: (application.tagging_data || {}).merge({
        'confie_mediacode' => media_code.to_s,
        'confie_reported' => true
      }))
    end
    return nil
  end

  REQUESTS = {
    online_policy_sale: {
      format: 'xml',
      endpoint: Rails.application.credentials.confie[:uri][ENV['RAILS_ENV'].to_sym]
    },
    create_lead: {
      format: 'json',
      endpoint: [
        Rails.application.credentials.confie[:lead_uri][:create][ENV['RAILS_ENV'].to_sym],
        Rails.application.credentials.confie[:partner_password_key][ENV['RAILS_ENV'].to_sym],
        Rails.application.credentials.confie[:campaign][ENV['RAILS_ENV'].to_sym],
      ].map{|v| v.chomp('/') }.join('/')
    },
    update_lead: {
      format: 'json',
      endpoint: Rails.application.credentials.confie[:lead_uri][:update][ENV['RAILS_ENV'].to_sym]
    }
  }

  STATUS_MAP = {
    'started' => 'in_progress',
    'in_progress' => 'in_progress',
    'complete' => 'quoted',
    'abandoned' => 'quoted',
    'quote_in_progress' => 'in_progress',
    'quote_failed' => 'in_progress',
    'quoted' => 'quoted',
    'more_required' => 'in_progress',
    'accepted' => 'accepted',
    'rejected' => 'quoted'
  }

  include HTTParty
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_accessor :compiled_rxml, :message_content,
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
      format: self.action == :online_policy_sale ? 'xml' : 'json',
      interface: 'REST',
      endpoint: self.endpoint_for(self.action),
      process: "confie_#{self.action}",
      request: self.action == :online_policy_sale ? self.compiled_rxml : self.message_content
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
    return REQUESTS[which_call][:endpoint]
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
    case self.action
      when :online_policy_sale
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
        end
        # handle response
        if call_data[:error]
          puts 'ERROR ERROR ERROR'.red
          pp call_data
        else
          call_data[:data] = call_data[:response].parsed_response
          # Bad result:   {"Envelope"=>{"Body"=>{"SubmitPolicyResponse"=>{"SubmitPolicyResult"=>{"ExternalId"=>nil, "SubmissionState"=>"UnexpectedError", "SubmissionStateDescription"=>"An error has occurred during parsing policy data", "PolicyId"=>nil}}}}}
          # Good result:  {"Envelope"=>{"Body"=>{"SubmitPolicyResponse"=>{"SubmitPolicyResult"=>{"ExternalId"=>"GC-1606249897-219099128", "SubmissionState"=>"Scheduled", "SubmissionStateDescription"=>"Policy has been scheduled for Import.", "PolicyId"=>nil}}}}}
          case call_data[:data].dig("Envelope", "Body", "SubmitPolicyResponse", "SubmitPolicyResult", "SubmissionState")
            when 'Scheduled'
              # it worked! yay and hooray! let the jubilation begin!!!
            when 'UnexpectedError'
              call_data[:error] = true
              call_data[:message] = "Request failed externally"
              call_data[:external_message] = call_data[:data].dig("Envelope", "Body", "SubmitPolicyResponse", "SubmitPolicyResult", "SubmissionStateDescription")
              call_data[:code] = 400 # the actual Response object gives code 200, what the heck?
            else
              call_data[:error] = true
              call_data[:message] = "Request failed externally"
              call_data[:external_message] = "No state description submitted"
              call_data[:code] = 400
          end
        end
      when :create_lead, :update_lead
        begin
          call_data[:response] = HTTParty.post(endpoint_for(self.action),
            body: self.action == :create_lead ? "data=#{message_content}" : message_content,
            headers: self.action == :create_lead ? {} : {
              'Content-Type' => 'application/json'
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
        end
        # handle response
        if call_data[:error]
          puts 'ERROR ERROR ERROR'.red
          pp call_data
        else
          case self.action
            when :create_lead
              call_data[:code] = call_data[:response].code
              if call_data[:response].code == 200
                call_data[:code] = call_data[:response].parsed_response&.[]('statuscode') || 500
              end
              if call_data[:code] != 200
                call_data[:error] = true
                call_data[:message] = "Request failed externally"
                call_data[:external_message] = (call_data[:response].parsed_response&.dig("error", "user_msg") rescue nil)
              end
            when :update_lead
              call_data[:code] = call_data[:response].code
              if call_data[:code] != 200
                call_data[:error] = true
                call_data[:message] = "Request failed externally"
                call_data[:external_message] = case call_data[:response].code
                  when 404;   "Lead not found"
                  when 422;   "Mediacode is invalid"
                  when 1001;  "Lead update contains invalid data"
                  when 1003;  "Lead outside updateable time range"
                  else;       "Unknown Error"
                end
              end
          end
        end
    end
    # scream to the console for the benefit of any watchers
    display_status = call_data[:error] ? 'ERROR' : 'SUCCESS'
    display_status_color = call_data[:error] ? :red : :green
    puts "#{'['.yellow} #{'Confie Service'.blue} #{']'.yellow}#{'['.yellow} #{display_status.colorize(display_status_color)} #{']'.yellow}: #{action.to_s.blue}"
    # all done
    return call_data
  end

  def build_create_lead(
    user:,
    lead_id:,
    address: user.address,
    **compilation_args
  )
    if address.nil?
      self.errors = { address: "cannot be blank" }
      return false
    end
    # put the request together
    self.action = :create_lead
    self.errors = nil
    self.message_content = {
      lead: {
        jornaya_lead_id: ENV['RAILS_ENV'] == 'production' ? nil : "8197cd0c-ff37-650b-0e7c-test",
        jornaya_lead_provider_code: ENV['RAILS_ENV'] == 'production' ? nil : "8197cd0c-ff37-650b-0e7c-test",
        id_lead: lead_id.to_s,
        date_partner: "#{ Time.now.strftime('%Y-%m-%d') }"
      }.compact,
      client: {
        first_name: user.profile.first_name,
        last_name: user.profile.last_name,
        phone: user.profile.contact_phone,
        email: user.email,
        gender: {'male'=>'male','female'=>'female','other'=>'non-binary'}[user.profile.gender],
        zipcode: address.nil? ? nil : user.address.zip_code,
        middle_name: user.profile.middle_name,
        address: address.nil? ? nil : address.combined_street_address,
        apt_suite: address.nil? ? nil : address.street_two,
        birth_date: user.profile.birth_date.strftime('%Y-%m-%d'),
        birth_month: user.profile.birth_date.strftime('%m')
      }.compact
    }.to_json # no auth here apparently... merge(get_auth_json).to_json
    return errors.blank?
  end

  def build_update_lead(
    id:,
    mediacode:,
    status:,
    **compilation_args
  )
    # put the request together
    self.action = :update_lead
    self.errors = nil
    self.message_content = {
      id: id.to_s,
      mediacode: mediacode&.to_s,
      data: {
        lead: {
          gc_status: ConfieService::STATUS_MAP[status]
        }
      }
    }.compact.merge(get_auth_json).to_json
    return errors.blank?
  end

  def build_online_policy_sale(
    policy:,
    **compilation_args
  )
    # put the request together
    self.action = :online_policy_sale
    self.errors = nil
    lobcd = get_lobcd_for_policy_type(policy.policy_type_id)
    if lobcd.nil?
      self.errors = ["Confie does not support policy type '#{policy.policy_type.title}'"]
    end
    first_invoice = policy.invoices.order("due_date asc").limit(1).take
    rquid = get_unique_identifier
    self.compiled_rxml = compile_xml({
      PersAutoPolicyQuoteInqRq: {
        RqUID: rquid,
        TransactionRequestDt: Time.current.to_date.to_s,
        LOBCd: lobcd[0],
        LOBSubCd: lobcd[1],
        InsuredOrPrincipal: (
          {
            'com.a1_ExternalId': rquid
          }.merge(get_insured_or_principal_for(
            policy.primary_user,
            nil,
            for_insurable: policy.primary_insurable || (policy.policy_type_id == ::PolicyType::RENT_GUARANTEE_ID ? true : nil)
          ))
        ),
        "com.a1_Policy": {
          NAICCd: 'undefined',
          ContractTerm: {
            EffectiveDt: policy.effective_date.to_s,
            ExpirationDt: policy.expiration_date.to_s,
            DurationPeriod: {
              NumUnits: 12
            }
          },
          LanguageCd: "EN",
          PolicyNumber: policy.number,
          CurrentTermAmt: {
            Amt: (first_invoice.total_due.to_d / 100.to_d).to_s
          },
          FullTermAmt: {
            Amt: (policy.policy_quotes.accepted.order("created_at desc").limit(1).take.policy_premium.total / 100.to_d).to_s
          },
          "com.a1_Payment": payment_info(
            policy.carrier.uses_stripe? ?
              first_invoice&.stripe_charges&.succeeded&.take
              : first_invoice
          ) || { MethodPaymentCd: "CreditCard", Amount: { Amt: (first_invoice.total_due.to_d / 100.to_d).to_s } },
          "com.a1_OnlineSalesFee": {
            Amt: "0.00"
          }
        }.merge(get_a1_policy_codes_for_policy_type(policy.policy_type_id)),
        "com.a1_OrganizationCd": "OLBT",
        "com.a1_InternalDocument": { URL: "NA" }
      }.merge({
        primary_insured: policy.primary_user.profile.full_name,
        additional_insured: policy.policy_users.select{|pu| !pu.primary }.map do |pu|
          pu.user.profile.full_name
        end,
        additional_interest: ((policy.policy_type_id == ::PolicyType::RESIDENTIAL_ID && policy.carrier_id == MsiService.carrier_id && !policy.account.nil?) ?
          policy.account.title
          : nil
        )
      }.transform_values{|v| v.blank? ? nil : v }.compact)

    }, **compilation_args)
    return errors.blank?
  end

  private

    def payment_info(charge)
      if charge.class.name == 'Invoice'
        return {
          MethodPaymentCd: "CreditCard",
          Amount: { Amt: (charge.total_due.to_d / 100.to_d).to_s },
          "com.a1_CreditCardInfo": {
            Number: 'NoData',
            "com.a1_CardHolder": {
              FirstName: charge.payer.profile.first_name,
              LastName: charge.payer.profile.last_name
            },
            BillingAddress: 'NoData' #{
            #  AddrTypeCd: 'BillingAddress',
            #  Street: "101 Main St",
            #  City: "Blacksburg",
            ##  StateProvCd: "VA",
             # PostalCode: "24060",
             # County: "Montgomery"
            #}
          }
        }
      else
        ch = Stripe::Charge.retrieve(charge.stripe_id) rescue nil
        #cust = Stripe::Customer.retrieve(ch.customer)
        case ch&.source&.object
          when "card"
            ba = address_from_stripe_source(ch.source)
            return {
              MethodPaymentCd: "CreditCard",
              Amount:  { Amt: (ch.amount.to_d / 100.to_d).to_s }, # don't know what a CurCd is, says it's optional
              "com.a1_CreditCardInfo": {
                # no credit card numbers for you, confie
                Number: 'NoData',
                "com.a1_CardHolder": { # MOOSE WARNING: stripe doesn't seem to have credit card name info, so pulling this from user right now
                  FirstName: charge&.invoice&.payer&.profile&.first_name || 'NoData',
                  LastName: charge&.invoice&.payer&.profile&.last_name || 'NoData'
                },
                #ExpirationYear: 'NoData',
                #ExpirationMonth: 'NoData'
              }.merge(ba.blank? ? {
                BillingAddress: 'NoData'
              } : {
                BillingAddress: ba
              })
            }
        end
      end
      return nil
    end

    def address_from_stripe_source(source)
      if source.address_city && source.address_line1 && source.address_state && source.address_zip
        {
          AddrTypeCd: "BillingAddress",
          Addr1: source.address_line1,
          Addr2: source.address_line2.blank? ? nil : source.address_line2,
          City: source.address_city,
          StateProvCd: source.address_state,
          PostalCode: source.address_zip
        }.compact
      end
      return nil
    end

    def get_insured_or_principal_for(obj, rolecd = nil, for_insurable: nil)
      case obj.class.name
        when 'User'
          return {
            'com.a1_DriverLicenseNumber': 'NA',
            GeneralPartyInfo:     obj.get_confie_general_party_info(for_insurable: for_insurable),
            PersonInfo: {
              BirthDt: obj.profile.birth_date&.to_s,
              GenderCd: {"male" => "M", "female" => "F", "unspecified" => "U", "other" => "U" }[obj.profile.gender],
              MaritalStatusCd: 'Unknown'
              # no further info for you, greedy confie
            }
          }
        when 'Account' # this isn't actually ever going to come up anymore
          return {
            GeneralPartyInfo:     obj.get_confie_general_party_info
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
          return ["HOME", "OLT"]
        when ::PolicyType::RESIDENTIAL_ID
          return ["HOME", "OLT"]
      end
      return nil
    end

    def get_unique_identifier
      "GC-#{Time.current.to_i.to_s}-#{rand(2**32)}"
    end

    def arrayify(val, nil_as_object: false)
      val.class == ::Array ? val : val.nil? && !nil_as_object ? [] : [val]
    end

    def get_auth_json
      {
        user_name: Rails.application.credentials.confie[:lead_username][ENV['RAILS_ENV'].to_sym],
        api_key: Rails.application.credentials.confie[:lead_key][ENV['RAILS_ENV'].to_sym]
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
              obj[:''].map{|k,v| "#{k}=\"#{v.to_s.gsub('&', '&amp;').gsub('"', '&quot;').gsub('<', '&lt;')}\"" }.join(" ")
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
                  "<#{k}#{subxml[:prop_string]}" + ((abbreviate_nils && subxml[:child_string].nil?) ? " />"
                    : (">#{subxml[:child_string].to_s}" + (closeless ? "" : "</#{k}>")))
                when :block
                  "<#{k}#{subxml[:prop_string]}" + ((abbreviate_nils && subxml[:child_string].nil?) ? " />"
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
          child_string = obj.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").split("\n").join("#{indent}\n")
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
                'a:Payload': some_xml#.gsub('<', '&lt;').gsub('>', '&gt;') (already done by json_to_xml, because I'm far too clever)
              }
            }
          }
        }
      }, line_breaks: line_breaks)
    end

end
