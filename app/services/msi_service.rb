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
    :request,
    :action,
    :rxml

  validates :action, 
    presence: true,
    format: {
      with: /GetOrCreateCommunity/QuotePolicy/BindPolicy/GetPolicyDetails/
    
      with: /getZipCode|PropertyInfo|getRates|getMinPrem|SendPolicyInfo|sendCancellationList|downloadAcordFile/, 
      message: 'must be from approved list' 
    }
  
  
  
  def get_or_create_community(
      :effective_date,
      :community_name, :number_of_units, :sales_rep_id, :property_manager_name, :years_professionally_managed, :year_built, :gated?,
      :address_line_one, :city, :state, :zip
  )
    json_req = {
      InsuranceSvcRq: {
        RenterPolicyQuoteInqRq: {
          MSI_CommunityInfo: {
            MSI_CommunityName:                community_name,
            MSI_CommunityYearsProfManaged:    years_professionally_managed,
            MSI_PropertyManagerName:          property_manager_name,
            MSI_NumberOfUnits:                number_of_units,
            MSI_CommunitySalesRepID:          sales_rep_id,
            MSI_CommunityYearBuilt:           year_built,
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
    }
    
  end
  
  
private

    def get_auth_json
      {
        SignonRq: {
          SignonPswd: {
            CustId: {
              CustLoginId: 0 # MOOSE WARNING: fill out details from enc
            },
            CustPswd: {
              Pswd: 'password' # MOOSE WARNING: fill this out w00t w00t
            }
          }
        }
      }
    end
    
    def json_to_xml(obj, abbreviate_nils: true, closeless: false, internal: false)
      prop_string = ""
      child_string = ""
      case obj
        when ::Hash
          if obj.has_key?(:'')
            prop_string = obj[:''].blank? ? "" : obj[:''].class == ::String ? obj[:''] :
              obj[:''].map{|k,v| "#{k}=\"#{v.to_s.gsub('"', '&quot;').gsub('&', '&amp;').gsub('<', '&lt;')}\"" }.join(" ")
            prop_string = " #{prop_string}" unless prop_string.blank?
            obj = obj.select{|k,v| k != :'' }
          end
          child_string = obj.map do |k,v|
            subxml = json_to_xml(v, abbreviate_nils: abbreviate_nils, internal: true)
            "<#{k}#{subxml[:prop_string]}" + ((abbreviate_nils && subxml[:child_string].nil?) ? "/>"
              : (">#{subxml[:child_string].to_s}" + (closeless ? "" : "</#{k}>")))
          end.join("")
        when ::NilClass
          child_string = nil
        else
          child_string = obj.to_s.gsub("<", "&lt;").gsub("<", "&gt;").gsub("&", "&amp;")
      end
      internal ? {
        prop_string: prop_string,
        child_string: child_string
      } : child_string
    end
  
end
