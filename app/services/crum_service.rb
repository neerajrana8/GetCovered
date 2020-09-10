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
			
      event = Event.new(
        verb: 'get', 
        format: 'json', 
        interface: 'REST',
        process: 'crum_get_class_codes', 
        endpoint: state_url,
        request: '{ "data": null }'
      )

			get_token()

			begin	
	    	request = HTTParty.get(state_url,
															 headers: {
																	 "Content-Type": "application/json",
																	 "Authorization": self.token["IdToken"]
															 })
	    rescue => e
	      pp e
	      error = true
	    end
	       
	    unless error
  	    event.response = request
  	    event.status = "success"
		  	request.each do |class_code|
			  	@carrier.carrier_class_codes.create(
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
		  else
		    event.status = "error"  
		  end
		  
		  event.save
  		
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
				"premise" => [
					{
						"owned" => false,
						"address" => {
							"city" => nil,
							"state" => nil,
							"county" => nil,
							"zip_code" => nil,
							"street_two" => nil,
							"street_name" => nil,
							"street_number" => nil
						},
			      "sub_class" => nil,
			      "class_code" => nil,
			      "major_class" => nil,
			      "sqr_footage" => 0,
			      "annual_sales" => 0,
			      "building_limit" => 0,
			      "full_time_employees" => 0,
			      "part_time_employees" => 0,
			      "business_personal_property_limit" => 0
			    }
			  ],
				"business" => {
					"phone" => nil,
					"address" => {
						"city" => nil,
						"state" => nil,
						"county" => nil,
						"zip_code" => nil,
						"street_two" => nil,
						"street_name" => nil,
						"street_number" => nil
				  },
		      "website" => nil,
		      "contact_name" => nil,
		      "business_name" => nil,
		      "business_type" => nil,
		      "contact_email" => nil,
		      "contact_phone" => nil,
		      "contact_title" => nil,
		      "business_started" => nil,
		      "number_of_insured" => 1,
		      "business_description" => nil,
		      "other_business_description" => nil
		    },
				"policy_limits" => {
					"building_limit" => 0,
					"aggregate_limit" => 0,
					"occurence_limit" => 0,
					"business_personal_property" => 0
				}
			}.merge!(args.fields)
  		            
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
  		          "applicantBusinessType": opts["business"]["business_type"],
  		          "insuredInformation": [
  		            {
  		              "numberOfInsured": opts["business"]["number_of_insured"],
  		              "businessName": opts["business"]["business_name"],
  		              "address1": "#{ opts["business"]["address"]["street_number"] } #{ opts["business"]["address"]["street_name"] }".strip,
  		              "address2": "",
  		              "city": opts["business"]["address"]["city"],
  		              "state": opts["business"]["address"]["state"],
  		              "zipCode": opts["business"]["address"]["zip_code"],
  		              "county": opts["business"]["address"]["county"],
  		              "primaryPhone": format_phone(opts["business"]["phone"]),
  		              "applicantWebsiteUrl": opts["business"]["website"]
  		            }
  		          ],
  		          "contactInformation": [
  		            {
  		              "contactName": opts["business"]["contact_name"],
  		              "contactTitle": opts["business"]["contact_title"],
  		              "contactPhone": format_phone(opts["business"]["contact_phone"]),
  		              "contactEmail": opts["business"]["contact_email"]
  		            }
  		          ],
  		          "natureOfBusiness": {
  		            "businessDateStarted": opts["business"]["business_started"].to_date.strftime('%Y-%m-%d'),
  		            "descriptionOfPrimaryOperation": opts["business"]["business_description"]
  		          },
  		          "premises": [],
  		          "otherBusinessVenture": "none"
  		        },
  		        "policy": {
  		          "effectiveDate": args.effective_date.to_date.strftime('%Y-%m-%d'),
  		          "expirationDate": args.expiration_date.to_date.strftime('%Y-%m-%d'),
  		          "liablityCoverages": {
  		            "liablityOccurence": opts["policy_limits"]["occurence_limit"],
  		            "liablityAggregate": opts["policy_limits"]["aggregate_limit"],
  		            "liablityBldgLimit": opts["policy_limits"]["building_limit"].nil? ? 0 : opts["policy_limits"]["building_limit"],
  		            "liablityPersonalPropertyLimit": opts["policy_limits"]["business_personal_property"].nil? ? 0 : opts["policy_limits"]["business_personal_property"]
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
			
			opts["premise"].each_with_index do |premise, index|
	      request_template[:quoteDetails][:policyService][:data][:account][:premises] << {
	        "locationNumber": "#{ index + 1 }",
	        "street": "#{ premise["address"]["street_number"] } #{ premise["address"]["street_name"] }.strip",
	        "city": premise["address"]["city"],
	        "state": premise["address"]["state"],
	        "county": premise["address"]["county"],
	        "zipCode": premise["address"]["zip_code"],
	        "premisesFullTimeEmployee": premise["full_time_employees"],
	        "premisesPartTimeEmployee": premise["part_time_employees"],
	        "occupancy": {
	          "majorClass": premise["major_class"],
	          "subClass": premise["sub_class"],
	          "classCode": premise["class_code"]
	        },
	        "isBuildingOwned": premise[:owned] == true ? "Yes" : "No",
	        "squareFootage": premise["sqr_footage"],
	        "annualSales": premise["annual_sales"],
	        "buildingLimit": premise["building_limit"],
	        "businessPropertyPersonallimit": premise["business_personal_property_limit"],
	        "eligible": ""
	      }
	   end
    
    elsif action == "get_document"
    
      request_template = {
        businessFunction: "quote",
        typeofLetter: "proposalLetter",
        businessTransactionId: nil
      }.merge!(args)
    
    elsif action == "bind"
      
      raise ArgumentError, 'Argument "args" must be a PolicyQuote' unless args.is_a?(PolicyQuote)
      
      request_template = {
        quoteId: "#{ args.external_id }",
        effectiveDate: args.policy_application.effective_date.strftime('%Y-%-m-%-d'),
        expirationDate: args.policy_application.expiration_date.strftime('%Y-%-m-%-d'),
        paymentMethod: "AgentBilling",
        paymentTerm: args.policy_application.billing_strategy.carrier_code,
        isTRIAIncluded: "No",
        producerEmail: "brandon@getcoveredllc.com",
        insuredName: args.policy_application.fields["business"]["contact_name"], 
        notes: "",
        notesRequestType:""      
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
	
	# CrumService.get_documents
	#
	
	def get_documents(data = {})
	  raise ArgumentError, 'Argument "data" cannot be nil' if data.nil?
	  
	  get_token()
	  
	  error = false
	  
		begin	
    	request = HTTParty.post(Rails.application.credentials.crum[:uri][:documents],
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