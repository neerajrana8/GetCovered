module Integrations
  module Yardi
    module RentersInsurance
      class CustomerSearch < Integrations::Yardi::RentersInsurance::Base
        string :property_id
        # these are all optional boyos to restrict the search
        string :first_name, default: nil
        string :last_name, default: nil
        string :description, default: nil
        string :organization_name, default: nil
        string :id, default: nil
        string :unit_id, default: nil
        
        def execute
          super(**{
            PropertyId: property_id,
            XMLDoc: get_customer_search_xml
          }.compact)
        end
        
        def get_customer_search_xml
          <<~XML
            <CustomerSearch xsi:schemaLocation="http://yardi.com/ResidentTransactions20 CustomerSearch.xsd" xmlns="" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
              <Request>
                <Customer>
                  <Identification>
                    #{ xml_block("IDValue", id) }
                    #{ xml_block("OrganizationName", organization_name) }
                  </Identification>
                  #{ xml_block("Description", description) }
                  <Name>
                    #{ xml_block("FirstName", first_name) }
                    #{ xml_block("LastName", last_name) }
                  </Name>
                </Customer>
                #{ xml_block("UnitID", unit_id) }
              </Request>
            </CustomerSearch>
          XML
        end
        
      end
    end
  end
end
