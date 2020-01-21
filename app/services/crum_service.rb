# Crum Service Model
# file: app/models/crum_service.rb
#
# Example:
#   >> @crum_service = CrumService.new({ attributes... })
#   => #<CrumService:0x0000000000000000 @request={}, @action="", @rxml="">

require "base64"
require 'fileutils'

class CrumService
  
  include HTTParty
  include ActiveModel::Validations
  include ActiveModel::Conversion
	include ActionView::Helpers::NumberHelper
  extend ActiveModel::Naming
  
  attr_accessor :action,
  							:token

  validates :action, 
    :presence => true,
    format: { 
      with: /quote|bind|/, 
      message: "must be from approved list" 
    }
  
  # CrumService.get_token
  # 
    
  def get_token
	  
	  call_data = {
      error: false,
      code: 200,
      message: nil,
      response: nil,
      data: nil
    }

    begin
      
      call_data[:response] = HTTParty.post(Rails.application.credentials.crum[:uri][:token],
                                   				 body: {
																					    "AuthParameters": {
																					        "USERNAME": Rails.application.credentials.crum[:auth][:un],
																					        "PASSWORD": Rails.application.credentials.crum[:auth][:pw]
																					    },
																					    "AuthFlow": "USER_PASSWORD_AUTH",
																					    "ClientId": Rails.application.credentials.crum[:client_id]
																					 }.to_json,
																	 				 headers: {
																	 				   "X-Amz-Target" => "AWSCognitoIdentityProviderService.InitiateAuth",
																	 				   "Content-Type" => "application/x-amz-json-1.1"
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
    
    unless call_data[:error] == true
    	token_data = JSON.parse(call_data[:response])
    	self.token = token_data['AuthenticationResult']
    end
    
    return call_data
    
	end
  
  # CrumService.refresh_all_class_codes
  # 
	
	def refresh_all_class_codes
		states().each do |state|
			get_class_code(state: state)	
		end
	end
  
  # CrumService.get_class_code
  # 
	
	def get_class_code(state: nil)
		
		# Find Crum and Forester
		@carrier = Carrier.find(3)
		@policy_type = PolicyType.find(3)
		
		url = Rails.application.credentials.crum[:uri][:class_codes].sub(':product', "BOP")
		
		if states().include?(state)
			
			state_url = url.sub(':state', state)
			error = false
				
			begin	
	    	request = HTTParty.get(state_url)
	    rescue => e
	      pp e
	      error = true
	    end
	       
	    unless error
		  	request.each do |class_code|
			  	@carrier.carrier_class_codes.create!(
			  		external_id: class_code["id"],
			  		major_category: class_code["MajorCategory"],
			  		sub_category: class_code["SubCategory"],
			  		class_code: class_code["ClassCode"],
			  		appetite: class_code["CFDPAppetite"] == "Yes" ? true : false,
			  		search_value: class_code["SearchValueBOP"],
			  		sic_code: class_code["SICCode"],
			  		eq: class_code["EQ"],
			  		eqsl: class_code["EQSL"],
			  		industry_program: class_code["IndustryProgram"],
			  		naics_code: class_code["NAICSCode"],
			  		state_code: class_code["StateCode"], 
			  		enabled: true, 
			  		policy_type: @policy_type) unless @carrier.carrier_class_codes
			  																							.exists?(external_id: class_code["id"])					
			  end  
		  end
		  
		end
		
	end
  
  # CrumService.format_phone(number)
  # 
  
	def format_phone(number = nil)
		raise ArgumentError, 'Argument "number" cannot be nil' if number.nil?
		modified_number = number.gsub(/\s+/,'')
		modified_number = modified_number.gsub(/[()-+.]/,'').tr('-', '')
		modified_number = modified_number.start_with?('1') &&
										  modified_number.length > 10 ? modified_number[1..-1] : 
																										modified_number
		return number_to_phone(modified_number)
	end 
	
	# CrumService.build_request_template
	# 
  
  def build_request_template(action = nil, args = {})
    
    request_template = nil
    
    if action == "add_new_quote"
      
      raise ArgumentError, 'Argument "args" must be a PolicyApplication' unless args.is_a?(PolicyApplication)
      
  		opts = {
  			user_email: args.primary_user().email,
  			policy_start_date: args.effective_date,
  			policy_end_date: args.expiration_date,
  			business: {
  				number_of_insured: args.fields["business"]["number_of_insured"],
  				business_name: args.fields["business"]["business_name"],
  				business_type: args.fields["business"]["business_type"],
  				phone: args.fields["business"]["phone"],
  				website: args.fields["business"]["website"],
  				contact_name: args.fields["business"]["contact_name"],
  				contact_title: args.fields["business"]["contact_title"],
  				contact_phone: args.fields["business"]["contact_phone"],
  				contact_email: args.fields["business"]["contact_email"],
  				business_started: args.fields["business"]["business_started"],
  				business_description: args.fields["business"]["business_description"],
  				full_time_employees: args.fields["business"]["full_time_employees"],
  				part_time_employees: args.fields["business"]["part_time_employees"],
  				major_class: args.fields["business"]["major_class"],
  				sub_class: args.fields["business"]["sub_class"],
  				class_code: args.fields["business"]["class_code"],	
  				annual_sales: args.fields["business"]["annual_sales"]	
  			},
  			premise: {
  				address: args.fields["premise"][0]["address"],
  				owned: args.fields["premise"][0]["owned"],	
  				sqr_footage: args.fields["premise"][0]["sqr_footage"],
  			},
  			policy_limits: {
  				liability: args.fields["policy_limits"]["liability"],
  				aggregate_limit:  args.fields["policy_limits"]["aggregate_limit"],
  				building_limit:  args.fields["policy_limits"]["building_limit"],
  				business_personal_property:  args.fields["policy_limits"]["business_personal_property"]			
  			}
  		}      

  		request_template = {
  		  "method": "AddNewUATQuote",
  		  "quoteDetails": {
  		    "policyService": {
  		      "policyHeader": {
  		        "serviceName": "BOPAddOrUpdatePolicy",
  		        "agencyReferenceID": Rails.application.credentials.crum[:client_id],
  		        "quoteNumber": "",
  		        "policyNumber": "",
  		        "userCredentials": {
  		          "userName": Rails.application.credentials.crum[:auth][:un]
  		        }
  		      },
  		      "data": {
  		        "producerInfo": {
  		          "name": "Get Covered LLC",
  		          "code": Rails.application.credentials.crum[:producer_code],
  		          "producerContactName": "Brandon Tobman",
  		          "producerEmail": "brandon@getcoveredllc.com"
  		        },
  		        "account": {
  		          "applicantBusinessType": opts[:business][:business_type],
  		          "insuredInformation": [
  		            {
  		              "numberOfInsured": opts[:business][:number_of_insured],
  		              "businessName": opts[:business][:business_name],
  		              "address1": "#{ opts[:premise][:address]["street_number"] } #{ opts[:premise][:address]["street_name"] }",
  		              "address2": "",
  		              "city": opts[:premise][:address]["city"],
  		              "state": opts[:premise][:address]["state"],
  		              "zipCode": opts[:premise][:address]["zip_code"],
  		              "county": opts[:premise][:address]["county"],
  		              "primaryPhone": format_phone(opts[:business][:phone]),
  		              "applicantWebsiteUrl": opts[:business][:website]
  		            }
  		          ],
  		          "contactInformation": [
  		            {
  		              "contactName": opts[:business][:contact_name],
  		              "contactTitle": opts[:business][:contact_title],
  		              "contactPhone": format_phone(opts[:business][:contact_phone]),
  		              "contactEmail": opts[:business][:contact_email]
  		            }
  		          ],
  		          "natureOfBusiness": {
  		            "businessDateStarted": opts[:business][:business_started].to_date.strftime('%Y-%m-%d'),
  		            "descriptionOfPrimaryOperation": opts[:business][:business_description]
  		          },
  		          "premises": [
  		            {
  		              "locationNumber": "1",
  		              "street": "#{ opts[:premise][:address]["street_number"] } #{ opts[:premise][:address]["street_name"] }",
  		              "city": opts[:premise][:address]["city"],
  		              "state": opts[:premise][:address]["state"],
  		              "county": opts[:premise][:address]["county"],
  		              "zipCode": opts[:premise][:address]["zip_code"],
  		              "premisesFullTimeEmployee": opts[:business][:full_time_employees],
  		              "premisesPartTimeEmployee": opts[:business][:part_time_employees],
  		              "occupancy": {
  		                "majorClass": opts[:business][:major_class],
  		                "subClass": opts[:business][:sub_class],
  		                "classCode": opts[:business][:class_code]
  		              },
  		              "isBuildingOwned": opts[:premise][:owned] == true ? "Yes" : "No",
  		              "squareFootage": opts[:premise][:sqr_footage],
  		              "annualSales": opts[:business][:annual_sales],
  		              "buildingLimit": opts[:policy_limits][:building_limit],
  		              "businessPropertyPersonallimit": opts[:policy_limits][:business_personal_property],
  		              "eligible": ""
  		            }
  		          ],
  		          "otherBusinessVenture": "none"
  		        },
  		        "policy": {
  		          "effectiveDate": opts[:policy_start_date].to_date.strftime('%Y-%m-%d'),
  		          "expirationDate": opts[:policy_end_date].to_date.strftime('%Y-%m-%d'),
  		          "liablityCoverages": {
  		            "liablityOccurence": opts[:policy_limits][:liability],
  		            "liablityAggregate": opts[:policy_limits][:aggregate_limit],
  		            "liablityBldgLimit": opts[:policy_limits][:building_limit],
  		            "liablityPersonalPropertyLimit": opts[:policy_limits][:business_personal_property]
  		          },
  		          "policyID": "",
  		          "quoteID": "",
  		          "product": "BOP",
  		          "productName": "194",
  		          "term": "",
  		          "quoteNumber": "",
  		          "policyNumber": "",
  		          "status": "",
  		          "transactionDate": Time.now.strftime('%Y-%m-%d'),
  		          "policyType": "New",
  		          "writingCompany": "07",
  		          "totalInsuredValuePerPolicy": "",
  		          "isUWAppetiteEligible": "",
  		          "termPremium": "",
  		          "priorPremium": "",
  		          "newPremium": "",
  		          "triaPremium": ""
  		        }
  		      },
  		      "Acceptabilityquestions": [
  		        {
  		          "questionId": "1",
  		          "questionResponse": "No"
  		        },
  		        {
  		          "questionId": "2",
  		          "questionResponse": "No"
  		        },
  		        {
  		          "questionId": "3",
  		          "questionResponse": "No"
  		        },
  		        {
  		          "questionId": "4",
  		          "questionResponse": "No"
  		        },
  		        {
  		          "questionId": "5",
  		          "questionResponse": "No"
  		        },
  		        {
  		          "questionId": "6",
  		          "questionResponse": "No"
  		        },
  		        {
  		          "questionId": "7",
  		          "questionResponse": "No"
  		        },
  		        {
  		          "questionId": "8",
  		          "questionResponse": "No"
  		        },
  		        {
  		          "questionId": "9",
  		          "questionResponse": "No"
  		        },
  		        {
  		          "questionId": "10",
  		          "questionResponse": "No"
  		        },
  		        {
  		          "questionId": "10A",
  		          "questionResponse": "No"
  		        },
  		        {
  		          "questionId": "11A",
  		          "questionResponse": "0"
  		        },
  		        {
  		          "questionId": "11B",
  		          "questionResponse": "0"
  		        },
  		        {
  		          "questionId": "11C",
  		          "questionResponse": "0"
  		        }
  		      ],
  		      "isEligible": "",
  		      "responseMessages": [
  		        {
  		          "responseCode": "",
  		          "responseMessage": ""
  		        }
  		      ]
  		    }
  		  }
  		}
      
    elsif action == "bind"
      
      raise ArgumentError, 'Argument "args" must be a PolicyQuote' unless args.is_a?(PolicyQuote)
      
      request_template = {
        policyID: args.external_id,
        quoteID: args.external_id,
        historyId:"",
        term: "0",
        quoteNumber: "BP1950Q2019.01",
        policyNumber: args.external_reference,
        policyStatus: "Quote",
        productnumber: "",
        transactionDate: Time.now.strftime('%Y-%-m-%-d'),                
        transactionStatus:"",
        transactionType:"",
        termPremium: args.policy_premium.carrier_base / 100,
        changePremium:"",
        priorPremium: "",
        newPremium:  args.policy_premium.carrier_base / 100,
        effectiveDate: args.policy_application.effective_date.strftime('%Y-%-m-%-d'),
        expirationDate: args.policy_application.expiration_date.strftime('%Y-%-m-%-d')   
      }
    
    end
    
    return request_template
    
  end
  
  # CrumService.add_new_quote(args)
  # 
	
	def add_new_quote(data = {})
		raise ArgumentError, 'Argument "data" cannot be nil' if data.nil?
		
		get_token()
		
		error = false
		
		begin	
    	request = HTTParty.post(Rails.application.credentials.crum[:uri][:add_quote],
    													body: data.to_json,
															headers: {
																"Content-Type": "application/json",
																"Authorization": self.token["IdToken"]
															})
    rescue => e
    	puts "ERROR\n".red
      error = true
    end
    
    return { 
      error: error,
      data: request
    }
				
	end
  
  # CrumService.bind(args)
  # 
	
	def bind(data = {})
		raise ArgumentError, 'Argument "data" cannot be nil' if data.nil?
		
		get_token()
		
		error = false
		
		begin	
    	request = HTTParty.post(Rails.application.credentials.crum[:uri][:bind],
    													body: data.to_json,
															headers: {
																"Content-Type": "application/json",
																"Authorization": self.token["IdToken"]
															})
    rescue => e
    	puts "ERROR\n".red
      error = true
    end
    
    return { 
      error: error,
      data: request
    }
    
	end
  
  # CrumService.states
  # method to return an array of state abbrivations
  
  def states
		return ["AK", "AL", "AR", "AZ", "CA", "CO", "CT", "DC", 
						"DE", "FL", "GA", "HI", "IA", "ID", "IL", "IN", 
						"KS", "KY", "LA", "MA", "MD", "ME", "MI", "MN", 
						"MO", "MS", "MT", "NC", "ND", "NE", "NH", "NJ", 
						"NM", "NV", "NY", "OH", "OK", "OR", "PA", "RI", 
						"SC", "SD", "TN", "TX", "UT", "VA", "VT", "WA", 
						"WI", "WV", "WY"]	  
	end
end