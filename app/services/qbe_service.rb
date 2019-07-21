# Qbe Service Model
# file: app/models/qbe_service.rb
#
# Example:
#   >> @net_service = NetService.new({ attributes... })
#   => #<QbeService:0x0000000000000000 @request={}, @action="", @rxml="">

require "base64"
require 'fileutils'

class QbeService
  
  include HTTParty
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming
  
  attr_accessor :compiled_rxml,
                :request,
                :action,
                :rxml

  validates :action, 
    :presence => true,
    format: { 
      with: /getZipCode|PropertyInfo|getRates|getMinPrem|SendPolicyInfo|sendCancellationList|downloadAcordFile/, 
      message: "must be from approved list" 
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
      send("#{name}=", value) unless name === "request"
    end
    
    self.request = {}
    self.build_request() unless self.action.nil?
  end
  
  # Get Binding
  # Bind object for use in XML templates
  #
  # Example:
  #   >> @qbe_service = QbeService.new({ attributes... })
  #   >> @qbe_service.get_binding()
  #   => #<QbeService>
  
  def get_binding
    return binding()
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
  
  def build_request(args = {}, build_request = true, post_compile_request = true, obj = nil, users = nil)
    
    options = {
      version: Rails.application.credentials.version, 
      heading: { 
        program: {
          name: "Renters",
          requesttimestamp: Time.current.strftime("%m/%d/%Y %I:%M %p"), 
          ClientName: Rails.application.credentials.qbe[:agent_code]
        }
      }
    }
    
    if self.action == "getZipCode"
      
      options[:data] = {
        type: "Zip Code Search", 
        senderID: Rails.application.credentials.qbe[:un], 
        receiverID: 32917, 
        prop_zipcode: 90034
      }.merge!(args)
       
      # / getZipCode
    elsif self.action == "PropertyInfo"
    
      options[:data] = {
        type: "PropertyInfo", 
        senderID: Rails.application.credentials.qbe[:un], 
        receiverID: 32917, 
        prop_number: 435,
        prop_street: "Serenity Lane",
        prop_city: "Del Boca Vista",
        prop_state: "FL",
        prop_zipcode: "32301"
      }.merge!(args)
      
      # / PropertyInfo
    elsif self.action == "getRates"
    
      options[:data] = {
        type: "Quote", 
        senderID: Rails.application.credentials.qbe[:un], 
        receiverID: 32917, 
        agent_id: Rails.application.credentials.qbe[:agent_code],
        current_system_date: Time.current.strftime("%m/%d/%Y"),
        prop_city: "San Francisco",
        prop_county: "SAN FRANCISCO",
        prop_state: "CA",
        prop_zipcode: 94115,
        pref_facility: "MDU",
        occupancy_type: "OTHER",
        units_on_site: 156,
        age_of_facility: 1991,
        gated_community: 0,
        prof_managed: 1,
        prof_managed_year: 1991,
        num_insured: 1,
        protection_device_code: 'F',
        constr_type: 'M',
        ppc_code: 1,
        effective_date: Time.current.strftime("%m/%d/%Y")
      }.merge!(args)
      
      # / getRates  
    elsif self.action == "getMinPrem"
    
      options[:data] = {
        type: "Quote", 
        senderID: Rails.application.credentials.qbe[:un], 
        receiverID: 32917, 
        agent_id: Rails.application.credentials.qbe[:agent_code],
        current_system_date: Time.current.strftime("%m/%d/%Y"),
        prop_city: "San Francisco",
        prop_county: "SAN FRANCISCO",
        prop_state: "CA",
        prop_zipcode: 94115,
        city_limit: 0,
        pref_facility: "MDU",
        occupancy_type: "OTHER",
        units_on_site: 156,
        age_of_facility: 1991,
        gated_community: 0,
        prof_managed: 1,
        prof_managed_year: 1991,
        effective_date: Time.current.strftime("%m/%d/%Y"),
        premium: 1.00,
        premium_pif: 0.75,
        num_insured: 1,
        lia_amount: 10000
      }.merge!(args)
      
      # / getMinPrem      
    elsif self.action == "SendPolicyInfo"
     
      unless obj.nil?
        options[:data] = {
          policy: obj,
          optional_rates: obj.rates.optional,
          community: obj.community,
          address: obj.community.address,
          user: obj.user,
          users: users,
          unit: obj.unit,
          invoice: obj.invoices.complete.first,
          account: obj.account
        }
      else
        return false
      end
          
      # / sendPolicyInfo
    elsif self.action == "sendCancellationList"
      
      request_time = Time.current
      policies_list = Array.new
      
      policies_list.concat Policy.accepted.unpaid.where(billing_behind_since: Time.current.to_date - 1.days)
      policies_list.concat Policy.accepted.rescinded
      
      options[:data] = {
        client_dt: request_time.strftime("%m/%d/%Y"),
        version: ENV.fetch("APP_VERSION"),
        rq_uid: "CL#{ request_time.strftime("%d%m%Y") }",
        transaction_request_date: request_time.strftime("%m/%d/%Y"),
        policies: policies_list
      }.merge!(args)
      
      # / sendCancellationList
    elsif self.action == "downloadAcordFile"
      
      # / downloadAcordFile
    else 
      
      return false
      # No known action    
    end
    # / case self.action
    
    self.request.merge!(options)
    self.build_request_file(post_compile_request) unless build_request == false
  end
  
  ##
  # Build Request File
  
  def build_request_file(post_compile=true)
    self.rxml = ERB.new(File.read("#{ Rails.root.to_s }/app/views/v2/qbe/#{ self.action }.xml.erb"))
    compile_request() unless post_compile === false
  end
  
  ##
  # Compile Request
  
  def compile_request
    self.compiled_rxml = self.rxml.result(get_binding())
    self.compiled_rxml.gsub!("\n",'')
    self.compiled_rxml.gsub!(/\n\t/, " ")
    self.compiled_rxml.gsub!(/>\s*</, "><")
  end
  
  # Call service
  # QbeService.call
  
  def call
    if self.action != "sendCancellationList" ||
       self.action != "downloadAcordFile"
			
      call_data = {
        error: false,
        code: 200,
        message: nil,
        response: nil,
        data: nil
      }

      begin
        
        call_data[:response] = HTTParty.post(Rails.application.credentials.qbe[:uri][Rails.application.credentials.rails_env.to_sym],
                                     				 body: self.compiled_rxml,
																		 				 headers: {
																		 				   "PreAuthenticate" => "TRUE",
																		 				 	 "Authorization" => "Basic #{ auth_headers }",
																		 				   "Content-Type" => "text/xml"
                                     				 })
            
      rescue => e
        
        puts "\nERROR\n"
        
        call_data = {
          error: true,
          code: 500,
          message: "Request Timeout",
          response: e
        }
      
      end
      
      unless call_data[:error]	
      	
      	call_data[:data] = call_data[:response].parsed_response["Envelope"]["Body"]["processRenterRequestResponse"]["xmlOutput"]
      	xml_doc = Nokogiri::XML(call_data[:data])
      	result = nil
      	
	      if self.action == "SendPolicyInfo"
					result = xml_doc.css('MsgStatusCd').children.to_s
					
					if !['SUCCESS', 'WARNING'].include?(result)
	      		call_data[:error] = true
	      		call_data[:message] = "Request Failed Externally"
	      		call_data[:code] = 409
					end
				else
	      	result = xml_doc.css('//result').attr('status').value
	      	
	      	if result != "pass"
	      		call_data[:error] = true
	      		call_data[:message] = "Request Failed Externally"
	      		call_data[:code] = 409
	      	end
				end
				
      else
      	
      	pp call_data
      	
      end
      
      display_status = call_data[:error] ? "ERROR" : "SUCCESS"
      display_status_color = call_data[:error] ? :red : :green
      # puts "#{ "[".yellow } #{ "QBE Service".blue } #{ "]".yellow }#{ "[".yellow } #{display_status.colorize(display_status_color)} #{ "]".yellow }: #{ action.to_s.blue }"
      
      return call_data
      
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
#             	status = result.attr('status').value
#             	
#             	puts status
#             	
# 	            if status == 'fail'
# 
# 		           call_response = {
# 		              error: true,
# 		              code: 500,
# 		              message: "QBE Service Request Failure"
# 		            }
# 		            
#             		pp call_response
#             	
#             	else
#             		display_error = false
#             	end
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

    elsif self.action == "sendCancellationList"
    
      return prepare_for_ftp(true) ? true : false
      
    elsif self.action == "downloadAcordFile"
      
      download_from_ftp()
    
    else
    
      return false
    
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
    
    if self.action == "sendCancellationList" && 
       self.request[:data][:policies].count > 0
      
      document = Document.new(
        :title => "#{ Time.current.strftime("%m/%d/%Y") } QBE Policy Cancellation List", 
        :system_generated => true, 
        :file_type => "policy_cancellation_file"
      )
      
      if document.save
        file_name = "GETCVR#{ Time.current.strftime('%Y%m%d') }.xml"
        
        # If Document did save
        save_path = Rails.root.join('tmp/policy_cancellation_files', file_name)
        
        FileUtils::mkdir_p "#{ Rails.root }/tmp/policy_cancellation_files"
        
        File.open(save_path, 'wb') do |file|
          file << self.compiled_rxml
        end
        
        document.file = Rails.root.join('tmp/policy_cancellation_files', file_name).open
        
        if document.save!
          Policy.accepted.rescinded.update_all(billing_status: 'current')
          if upload 
            FileUtils::remove_entry(Rails.root.join('tmp/policy_cancellation_files', file_name))
            return upload_to_ftp("tmp/policy_cancellation_files/#{ file_name }") ? true : false
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
    
      return false
      
    end
  end
  
  # Upload to FTP
  #
  
  def upload_to_ftp(tmp_file_path = nil)
    unless tmp_file_path.nil?
      net_service = NetService.new(:action => 'upload', 
                                   :path =>  '/nfs/c04/h05/mnt/182582/users/.home', 
                                   :file =>  tmp_file_path)

      return net_service.upload() ? true : false
    else
      return false
    end
  end
  
  # Download From FTP
  #
  # Download and return XML Acord file from QBE's servers
  
  def download_from_ftp
    if self.action == "downloadAcordFile"
    
      net_service = NetService.new()
    
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
  
  def cancellation_codes
    return ["AP", "AR", "CP", "CR", "FC", "ID", "IP", "IR", 
            "IS", "LU", "MR", "NP", "RE", "SC", "SD", "SR", 
            "UA", "UC", "UD", "UI", "UL", "UM", "UR", "UU", 
            "UW", "VN"]  
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
    return ["F", "S", "B", "FB", "SB"]  
  end
  
  private
    
    def auth_headers
      return Base64.encode64("#{ Rails.application.credentials.qbe[:un] }:#{ Rails.application.credentials.qbe[:pw] }")  
    end
end