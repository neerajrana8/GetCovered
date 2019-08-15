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
  extend ActiveModel::Naming
  
  attr_accessor :action,
  							:token

  validates :action, 
    :presence => true,
    format: { 
      with: /quote|bind|/, 
      message: "must be from approved list" 
    }
    
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
	
	def refresh_all_class_codes
		states().each do |state|
			get_class_code(state: state)	
		end
	end
	
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
			  		appetite: class_code["CFDPAppetite"],
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
	
	def add_new_quote
		
		get_token()
		
		request_template = {
		  "method": "AddNewBOPQuote",
		  "quoteDetails": {
		    "policyService": {
		      "policyHeader": {
		        "serviceName": "",
		        "agencyReferenceID": "",
		        "quoteNumber": "",
		        "policyNumber": "",
		        "userCredentials": {
		          "userName": "username@email.com"
		        }
		      },
		      "data": {
		        "producerInfo": {
		          "name": "Producer Name",
		          "code": "12345",
		          "producerContactName": "Producer Contact Name",
		          "producerEmail": "Producer Contact Email"
		        },
		        "account": {
		          "applicantBusinessType": "Business Type ",
		          "insuredInformation": [
		            {
		              "numberOfInsured": "1",
		              "businessName": "Businees Name",
		              "address1": "Address1",
		              "address2": "address2",
		              "city": "City",
		              "state": "State",
		              "zipCode": "1234",
		              "county": "county",
		              "primaryPhone": "714-965-1776",
		              "applicantWebsiteUrl": "http://website.com/"
		            }
		          ],
		          "contactInformation": [
		            {
		              "contactName": "contactName",
		              "contactTitle": "contactTitle",
		              "contactPhone": "contactPhone",
		              "contactEmail": "contactEmail"
		            }
		          ],
		          "natureOfBusiness": {
		            "businessDateStarted": "businessDateStarted",
		            "descriptionOfPrimaryOperation": "descriptionOfPrimaryOperation"
		          },
		          "premises": [
		            {
		              "locationNumber": "1",
		              "street": "street",
		              "city": "city",
		              "state": "state",
		              "county": "county",
		              "zipCode": "92646",
		              "premisesFullTimeEmployee": "1",
		              "premisesPartTimeEmployee": "0",
		              "occupancy": {
		                "majorClass": "majorClass",
		                "subClass": "subClass",
		                "classCode": "classCode"
		              },
		              "isBuildingOwned": "No",
		              "squareFootage": "0000",
		              "annualSales": "0000",
		              "buildingLimit": "0000",
		              "businessPropertyPersonallimit": "000000",
		              "eligible": ""
		            }
		          ],
		          "otherBusinessVenture": "none"
		        },
		        "policy": {
		          "effectiveDate": "2019-06-10",
		          "expirationDate": "2020-05-10",
		          "liablityCoverages": {
		            "liablityOccurence": "00000",
		            "liablityAggregate": "00000",
		            "liablityBldgLimit": "00000",
		            "liablityPersonalPropertyLimit": "00000"
		          },
		          "policyID": "",
		          "quoteID": "",
		          "product": "BOP",
		          "productName": "194",
		          "term": "",
		          "quoteNumber": "",
		          "policyNumber": "",
		          "status": "",
		          "transactionDate": "2019-05-08",
		          "policyType": "New",
		          "writingCompany": "07",
		          "totalInsuredValuePerPolicy": "",
		          "isUWAppetiteEligible": "",
		          "termPremium": "",
		          "priorPremium": "",
		          "newPremium": ""
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

				
	end
  
  # states
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