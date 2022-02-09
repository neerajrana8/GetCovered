# Qbe Service Model
# file: app/models/qbe_service.rb
#
# Example:
#   >> @qbe_service = QbeService.new({ attributes... })
#   => #<QbeService:0x0000000000000000 @request={}, @action="", @rxml="">

require 'base64'
require 'fileutils'

class QbeService

  FIC_DEFAULT_KEYS = [ # add new entries to policy_application_contr.qbe_application in the locale files when adding to this
    "year_built",
    "number_of_units",
    "gated",
    "years_professionally_managed",
    "in_city_limits"
  ]

  FIC_DEFAULTS = {
    nil => { # default defaults
      "year_built" => '1996',
      "number_of_units" => 40,
      "gated" => false,
      "years_professionally_managed" => 0,
      "in_city_limits" => false
    },
    'AZ' => {
      "year_built" => '1994',
      "number_of_units" => 150,
      "gated" => false,
      "years_professionally_managed" => 2,
      "in_city_limits" => false
    },
    'WA' => {
      "in_city_limits" => false
    },
    'FL' => {
      "in_city_limits" => false
    }
  }.merge(['CO', 'DC', 'GA', 'IL', 'IN', 'LA', 'MA', 'MD', 'MI', 'MO', 'NV', 'OH', 'PA', 'SC', 'TN', 'TX', 'UT', 'VA'].map do |state|
    [state, {
      "year_built" => '1996',
      "number_of_units" => 1,
      "gated" => false,
      "years_professionally_managed" => 0,
      "in_city_limits" => false
    }]
  end.to_h)
  
  DEDUCTIBLE_CALCULATIONS = { # WARNING: note that this is in dollars for readability
    'DEFAULT' => {
      250 => { 'wind' => 1000, 'theft' => 500 },
      500 => { 'wind' => 1000 }
    },
    'AR' => {
      'wind_absent' => true,
      250 =>  { 'theft' => 500 },
      500 =>  {},
      1000 => {}
    },
    'CT' => {
      'wind_absent' => true,
      250 => { 'theft' => 500 },
      500 => {},
      1000 => {}
    },
    'FL' => { 'wind_absent' => true, 'theft_absent' => true }, #MOOSE WARNING: nothing said about theft & wind... 
    'NC' => {},
    'NY' => {
      'wind_absent' => true,
      250 => { 'theft' => 500 }
    }
  }
  
  def self.get_applicability(community, traits, cip: nil)
    # get the CIP
    cip = community.carrier_profile(1) if cip.nil?
    if cip.nil?
      community.create_carrier_profile(1)
      cip = community.carrier_profile(1)
    end
    # filter the traits
    traits = traits.transform_keys{|k| k.to_s }
    return cip.traits.map do |k,v|
      [k, traits.has_key?(k) ? traits[k] : v]
    end.to_h
  end

  def self.carrier_id
    1
  end
  
  def self.carrier
    @carrier ||= ::Carrier.find(1)
  end
  
  include HTTParty
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_accessor :compiled_rxml,
    :request,
    :action,
    :rxml

  validates :action,
    presence: true,
    format: {
      with: /getZipCode|PropertyInfo|getRates|getMinPrem|SendPolicyInfo|sendCancellationList|downloadAcordFile/,
      message: 'must be from approved list'
    }

  # Initialize
  #
  # Params:
  # +attributes+:: (Hash) {}
  #
  # Example:
  #   >> @qbe_service = QbeService.new({ attributes... })
  #   => nil

  def initialize(attributes = {})
    attributes.each do |name, value|
      send("#{name}=", value) unless name === 'request'
    end

    self.request = {}
    build_request unless action.nil?
  end

  # Get Binding
  # Bind object for use in XML templates
  #
  # Example:
  #   >> @qbe_service = QbeService.new({ attributes... })
  #   >> @qbe_service.get_binding()
  #   => #<QbeService>

  def get_binding
    binding
  end

  # Persisted
  # Ensure object is never saved to database
  #
  # Example:
  #   >> @qbe_service = QbeService.new({ attributes... })
  #   >> @qbe_service.persisted?
  #   => false

  def persisted?
    false
  end

  # Build Request
  # Buid request object from args with defaults
  #
  # Params:
  # +args+:: (Hash) {}
  # +build_request+:: (Boolean) Defaults to true
  # +post_compile_request+:: (Boolean) Defaults to true
  #
  # Example
  #   >> @qbe_service = QbeService.new({ attributes... })
  #   >> @abe_service.build_request({ args... })
  #   => nil

  def build_request(args = {}, build_request = true, post_compile_request = true, obj = nil, _users = nil)

    options = {
      version: Rails.application.credentials.version,
      heading: {
        program: {
          name: 'Renters',
          requesttimestamp: Time.current.strftime('%m/%d/%Y %I:%M %p'),
          ClientName: Rails.application.credentials.qbe[:agent_code]
        }
      }
    }

    if action == 'getZipCode'
      options[:data] = {
        type: 'Zip Code Search',
        senderID: Rails.application.credentials.qbe[:un],
        receiverID: 32_917,
        prop_zipcode: 90_034
      }.merge!(args)

      options[:heading][:program][:ClientName] = args[:agent_code]

      # / getZipCode
    elsif action == 'PropertyInfo'
      options[:data] = {
        type: 'PropertyInfo',
        senderID: Rails.application.credentials.qbe[:un],
        receiverID: 32_917,
        prop_number: 435,
        prop_street: 'Serenity Lane',
        prop_city: 'Del Boca Vista',
        prop_state: 'FL',
        prop_zipcode: '32301'
      }.merge!(args)

      options[:heading][:program][:ClientName] = args[:agent_code] || Rails.application.credentials.qbe[:agent_code]

      # / PropertyInfo
    elsif action == 'getRates'

      options[:data] = {
        type: 'Quote',
        senderID: Rails.application.credentials.qbe[:un],
        receiverID: 32_917,
        agent_id: Rails.application.credentials.qbe[:agent_code],
        current_system_date: Time.current.strftime('%m/%d/%Y'),
        prop_city: 'San Francisco',
        prop_county: 'SAN FRANCISCO',
        prop_state: 'CA',
        prop_zipcode: 94_115,
        pref_facility: 'FIC',
        occupancy_type: 'OTHER',
        units_on_site: 156,
        age_of_facility: 1991,
        gated_community: 0,
        prof_managed: 1,
        prof_managed_year: 1991,
        num_insured: 1,
        protection_device_code: 'F',
        constr_type: 'M',
        ppc_code: nil,
        bceg_code: nil,
        effective_date: (Time.current + 1.day).strftime('%m/%d/%Y')
      }.merge!(args)

      options[:heading][:program][:ClientName] = args[:agent_code] || Rails.application.credentials.qbe[:agent_code]

      # / getRates
    elsif action == 'getMinPrem'

      options[:data] = { # values that reeeally shouldn't be defaulted if not provided are commented out here
        type: 'Quote',
        senderID: Rails.application.credentials.qbe[:un],
        receiverID: 32_917,
        agent_id: Rails.application.credentials.qbe[:agent_code],
        current_system_date: Time.current.strftime('%m/%d/%Y'),
        # prop_city: 'San Francisco',
        # prop_county: 'SAN FRANCISCO',
        # prop_state: 'CA',
        # prop_zipcode: 94_115,
        pref_facility: 'FIC',
        occupancy_type: 'OTHER',
        # city_limit: 0,
        # units_on_site: 156,
        # age_of_facility: 1991,
        # gated_community: 0,
        # prof_managed: 1,
        # prof_managed_year: 1991,
        effective_date: Time.current.strftime('%m/%d/%Y'),
        premium: 1.00,
        premium_pif: 0.75,
        num_insured: 1,
        lia_amount: 10_000
      }.merge!(args)

      options[:heading][:program][:ClientName] = args[:agent_code] || Rails.application.credentials.qbe[:agent_code]

      # / getMinPrem
    elsif action == 'SendPolicyInfo'

      if obj.nil?
        return false
      else

        application = obj.policy_application
        premium = obj.policy_premium
        address = application.primary_insurable().primary_address()
        cip = application.primary_insurable.parent_community.carrier_profile(1)

        options[:data] = {
          quote: obj,
          application: application,
          premium: premium,
          billing_strategy: application.billing_strategy,
          community: application.primary_insurable().parent_community(),
          carrier_profile: application.primary_insurable().parent_community().carrier_profile(1),
          address: address,
          county: cip.data&.[]("county_resolution")&.[]("matches")&.find{|m| m["seq"] == cip.data["county_resolution"]["selected"] }&.[]("county") || address.county, # we use the QBE formatted one in case .titlecase killed dashes etc.
          user: application.policy_users.where(primary: true).take,
          users: application.policy_users.where.not(primary: true),
          unit: application.primary_insurable,
          account: application.primary_insurable.account_id ? application.primary_insurable.account : nil, # PM account is passed as additional interest
          pm_info: application.extra_settings&.[]('additional_interest'), # if account is nil, will use this instead unless blank
          agency: application.agency,
          units_on_site: application.primary_insurable.parent_community.units.confirmed.count,
          coverage_selections: application.coverage_selections
        }.merge!(args)

        options[:heading][:program][:ClientName] = args[:agent_code] || Rails.application.credentials.qbe[:agent_code]

      end

      # / sendPolicyInfo
    elsif action == 'sendCancellationList'

      request_time = Time.current
      policies_list = []

      policies_list.concat Policy.current.unpaid.where(billing_behind_since: Time.current.to_date - 1.days)
      policies_list.concat Policy.current.RESCINDED

      options[:data] = {
        client_dt: request_time.strftime('%m/%d/%Y'),
        version: ENV.fetch('APP_VERSION'),
        rq_uid: "CL#{request_time.strftime('%d%m%Y')}",
        transaction_request_date: request_time.strftime('%m/%d/%Y'),
        policies: policies_list
      }.merge!(args)

      # / sendCancellationList
    elsif action == 'downloadAcordFile'

      # / downloadAcordFile
    else

      return false
      # No known action
    end
    # / case self.action
    request.merge!(options)
    build_request_file(post_compile_request) unless build_request == false
  end

  ##
  # Build Request File

  def build_request_file(post_compile = true)
    self.rxml = ERB.new(File.read("#{Rails.root}/app/views/v2/qbe/#{action}.xml.erb"))
    compile_request unless post_compile === false
  end

  ##
  # Compile Request

  def compile_request
    self.compiled_rxml = rxml.result(get_binding)
    compiled_rxml.delete!("\n")
    compiled_rxml.gsub!(/\n\t/, ' ')
    compiled_rxml.gsub!(/>\s*</, '><')
  end

  # Call service
  # QbeService.call

  def call
    if action != 'sendCancellationList' &&
       action != 'downloadAcordFile'

      call_data = {
        error: false,
        code: 200,
        message: nil,
        response: nil,
        data: nil
      }

      begin
        call_data[:response] = HTTParty.post(Rails.application.credentials.qbe[:uri][ENV['RAILS_ENV'].to_sym],
          timeout: 90, # added to prevent timeout after 15s
          body: compiled_rxml,
          headers: {
            'PreAuthenticate' => 'TRUE',
            'Authorization' => "Basic #{auth_headers}",
            'Content-Type' => 'text/xml'
          })

      rescue StandardError => e

        puts "\nERROR\n"

        call_data = {
          error: true,
          code: 500,
          message: 'Request Timeout',
          response: e
        }

        ActionMailer::Base.mail(from: 'info@getcoveredinsurance.com', to: 'dev@getcoveredllc.com', subject: "QBE #{ action } error", body: call_data.to_json).deliver

      end

      if call_data[:error]

        puts 'ERROR ERROR ERROR'.red
        pp call_data

      else
        call_data[:data] = call_data[:response].parsed_response['Envelope']['Body']['processRenterRequestResponse']['xmlOutput']
        xml_doc = Nokogiri::XML(call_data[:data])
        result = nil

        if action == 'SendPolicyInfo'

          result = xml_doc&.css('MsgStatusCd')&.children.to_s

          unless %w[SUCCESS WARNING].include?(result)
            call_data[:error] = true
            call_data[:message] = 'Request Failed Externally'
            call_data[:code] = 409
          end
        else
          result = xml_doc&.css('//result')&.attr('status')&.value

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

    #       display_error = true
    #
    #       begin
    #
    #         soap_request = HTTParty.post(Rails.application.credentials.qbe[:uri],
    #                                      body: self.compiled_rxml,
    #                                      headers: {
    #                                        "PreAuthenticate" => "TRUE",
    #                                        "Authorization" => "Basic #{ auth_headers }",
    #                                        "Content-Type" => "text/xml"
    #                                      })
    #       rescue e
    #
    #         call_response = {
    #           error: true,
    #           code: 500,
    #           message: "Request Timeout",
    #           response: e
    #         }
    #
    #       end
    #
    #       unless call_response[:error] == true
    #
    #         if soap_request.code == 200
    #
    #           unless soap_request.parsed_response["Envelope"]["Body"]["processRenterRequestResponse"].nil?
    #             call_response = soap_request.parsed_response["Envelope"]["Body"]["processRenterRequestResponse"]["xmlOutput"]
    #
    #             xml_doc = Nokogiri::XML(call_response)
    #             result = xml_doc.css('//result')
    #
    #             unless result.nil?
    #               status = result.attr('status').value
    #
    #               puts status
    #
    #               if status == 'fail'
    #
    #                call_response = {
    #                   error: true,
    #                   code: 500,
    #                   message: "QBE Service Request Failure"
    #                 }
    #
    #                 pp call_response
    #
    #               else
    #                 display_error = false
    #               end
    #             end
    #
    #           else
    #             call_response = {
    #               error: true,
    #               code: 500,
    #               message: "Blank Response"
    #             }
    #           end
    #
    #         else
    #
    #           call_response = {
    #             error: true,
    #             code: soap_request.code
    #           }
    #
    #         end
    #       end
    #
    #       display_status = display_error == true ? "ERROR" : "SUCCESS"
    #       display_status_color = display_status == "ERROR" ? :red : :green
    #       puts "#{ "[".yellow } #{ "QBE Service".blue } #{ "]".yellow }#{ "[".yellow } #{display_status.colorize(display_status_color)} #{ "]".yellow }: #{ action.to_s.blue }"
    #
    #       return call_response

    elsif action == 'sendCancellationList'
      prepare_for_ftp(true) ? true : false
    elsif action == 'downloadAcordFile'
      download_from_ftp
    else
      false
    end
  end

  # Prepare for FTP
  #
  # Buid xml file for uploading to QBE FTP Server
  #
  # Example
  #   >> @qbe_service = QbeService.new({ attributes... })
  #   >> @abe_service.build_request({ args... })
  #   >> @abe_service.upload_to_ftp
  #   => true

  def prepare_for_ftp(upload = false)

    if action == 'sendCancellationList' && request[:data][:policies].count > 0

      document = Document.new(
        title: "#{Time.current.strftime('%m/%d/%Y')} QBE Policy Cancellation List",
        system_generated: true,
        file_type: 'policy_cancellation_file'
      )

      if document.save
        file_name = "GETCVR#{Time.current.strftime('%Y%m%d')}.xml"

        # If Document did save
        save_path = Rails.root.join('tmp/policy_cancellation_files', file_name)

        FileUtils.mkdir_p "#{Rails.root}/tmp/policy_cancellation_files"

        File.open(save_path, 'wb') do |file|
          file << compiled_rxml
        end

        document.file = Rails.root.join('tmp/policy_cancellation_files', file_name).open

        if document.save!
          Policy.accepted.rescinded.update_all(billing_status: 'current')
          if upload
            return upload_to_ftp("tmp/policy_cancellation_files/#{file_name}")
          else
            return true
          end
        else
          return false
        end
      else
        # If Document did not save
        return false
      end
    else
      false
    end
  end

  # Upload to FTP
  #

  def upload_to_ftp(tmp_file_path = nil)
    if tmp_file_path.nil?
      false
    else
      NetService.new.upload(tmp_file_path)
    end
  end

  # Download From FTP
  #
  # Download and return XML Acord file from QBE's servers

  def download_from_ftp
    if action == 'downloadAcordFile'
      net_service = NetService.new
      acord_file_path = '/path/to/file'
      local_file_path = '/path/to/file'
      net_service.download(acord_file_path, local_file_path)
    end
  end

  # Resolve QBE Acord File Data
  #
  # Extract and act upon necessary information from daily
  # Acord file download

  def resolve_qbe_acord_file_data(acord_data = nil)
    unless acord_data.nil?

      xml_doc = Nokogiri::XML(acord_data)

      # Run Update Logic

    end
  end

  # Cancellation Codes
  #
  # Returns an array of QBE cancellation codes as strings
  #
  # [AP] Non-Pay *(System Generated)*
  # [AR] Agent Request
  # [CP] Company Procedures *(Currently Unavailable)*
  # [CR] Cancel and Rewrite *(Currently Unavailable)*
  # [FC] Foreclosure *(Currently Unavailable)*
  # [ID] Insured Deceased *(Currently Unavailable)*
  # [IP] Coverage Placed Elsewhere *(Currently Unavailable)*
  # [IR] Insured's Request
  # [IS] Business Sold/Insured Moved *(Currently Unavailable)*
  # [LU] Lack of Underwriting Information *(Currently Unavailable)*
  # [MR] Mortgagee Request *(Currently Unavailable)*
  # [NP] Non-Pay New Application
  # [RE] Expired Renewal *(Currently Unavailable)*
  # [SC] Substantial Change in Exposure *(Currently Unavailable)*
  # [SD] Sold Dwelling *(Currently Unavailable)*
  # [SR] Suspended/Revoked DL *(Currently Unavailable)*
  # [UA] Agent No Longer Represents Company *(Currently Unavailable)*
  # [UC] Change in Company Requirements *(Currently Unavailable)*
  # [UD] Driving Record *(Currently Unavailable)*
  # [UI] Underwriting Information is Incomplete *(Currently Unavailable)*
  # [UL] Loss History *(Currently Unavailable)*
  # [UM] Misrepresentation on Application *(Currently Unavailable)*
  # [UR] Change of Risk *(Currently Unavailable)*
  # [UU] Unfavorable Report *(Currently Unavailable)*
  # [UW] Cancellation by Underwriter
  # [VN] Vacant/Non-owner Occupied Property *(Currently Unavailable)*

  CANCELLATION_REASON_MAPPING = [
    { code: 'AP', reason: 'nonpayment' },
    { code: 'AR', reason: 'agent_request' },
    { code: 'IR', reason: 'insured_request' },
    { code: 'NP', reason: 'new_application_nonpayment' },
    { code: 'UW', reason: 'underwriter_cancellation' }
  ]


  def cancellation_codes
    %w[AP AR CP CR FC ID IP IR
       IS LU MR NP RE SC SD SR
       UA UC UD UI UL UM UR UU
       UW VN]
  end

  # Protection Device Codes
  #
  # Returns an array of QBE Protection Device codes as strings
  #
  # [F] Fire
  # [S] Sprinkler
  # [B] Burgler
  # [FB] Fire & Burgler
  # [SB] Sprinkler & Burgler

  def production_device_codes
    %w[F S B FB SB]
  end
  
  
  def self.validate_qbe_additional_interest(hash)
    case hash['entity_type']
      when 'company'
        return 'msi_service.additional_interest.company_name_required' if hash['company_name'].blank?
      when 'person'
        return 'msi_service.additional_interest.first_name_required' if hash['first_name'].blank?
        return 'msi_service.additional_interest.last_name_required' if hash['last_name'].blank?
      else
        return 'msi_service.additional_interest.invalid_entity_type'
    end
    return 'qbe_service.additional_interest.address_line_1_required' if hash['addr1'].blank?
    return 'qbe_service.additional_interest.address_city_required' if hash['city'].blank?
    return 'qbe_service.additional_interest.address_state_required' if hash['state'].blank?
    return 'qbe_service.additional_interest.address_state_invalid' if !hash['state'].blank? && !::Address.states.keys.include?(hash['state'].upcase)
    return 'qbe_service.additional_interest.address_zip_required' if hash['zip'].blank?
    return 'qbe_service.additional_interest.address_zip_invalid' if !hash['zip'].blank? && (case hash['zip'].size; when 5; !hash['zip'].scan(/\D/).blank?; when 10; hash['zip'][5] != '-' || hash['zip'].scan(/\D/) != '-'; else; true; end)
    return nil
  end

  private

    def auth_headers
      Base64.encode64("#{Rails.application.credentials.qbe[:un]}:#{Rails.application.credentials.qbe[:pw][ENV["RAILS_ENV"].to_sym]}")
    end
end
