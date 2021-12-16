module Integrations
  module Yardi
    module BillingAndPayments
      class ImportResidentTransactions < Integrations::Yardi::BillingAndPayments::Base
        object :invoice, default: nil     # the invoice to make a charge for
        string :charge_xml, default: nil  # optionally, provide charge xml directly
        hash :charge_hash, default: nil, strip: false # optionally, charge hash to convert to xml
        
        def execute
          super(**{
            TransactionXml: charge_xml || get_new_charge_xml_from_hash || get_new_charge_xml # use Charges to get "Object reference not set to an instance of an object." error; docs say TransactionXml
          }.compact)
        end
        
        def action # override action to add the goofy "_Login"
          "ImportResidentTransactions_Login"
        end
        
        def get_new_charge_xml_from_hash
          harsh = charge_hash.deep_stringify_keys
          strang = ""
          #strang += '<ResidentTransactions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://yardi.com/ResidentTransactions20" xsi:schemaLocation="http://yardi.com/ResidentTransactions20 C:\Users\kylec\Documents\_QA\_Interfaces\XSD\Itf_MITS_ResidentTransactions2.0.xsd">' + "\n"
          strang += '<ResidentTransactions>' + "\n"
          strang += "  <Property>\n"
          strang += "    <RT_Customer>\n"
          strang += "      <RTServiceTransactions>\n"
          strang += "        <Transactions>\n"
          strang += "          <Charge>\n"
          strang += "            <Detail>\n"
          harsh.each do |prop, val|
            strang += "              <#{prop}>#{val}</#{prop}>\n"
          end
          strang += "            </Detail>\n"
          strang += "          </Charge>\n"
          strang += "        </Transactions>\n"
          strang += "      </RTServiceTransactions>\n"
          strang += "    </RT_Customer>\n"
          strang += "  </Property>\n"
          strang += "</ResidentTransactions>"
          return strang
        end
        
        def get_new_charge_xml
          
          #  <RT_Customer><RTServiceTransactions><Transactions>
          # </Transactions></RTServiceTransactions></RT_Customer>
          
          
          return <<~XML
            <ResidentTransactions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://yardi.com/ResidentTransactions20" xsi:schemaLocation="http://yardi.com/ResidentTransactions20 C:\Users\kylec\Documents\_QA\_Interfaces\XSD\Itf_MITS_ResidentTransactions2.0.xsd">
              <Property>
                <RT_Customer>
                  <RTServiceTransactions>
                    <Transactions>
                      <Charge>
                        <Detail>
                          <Description>Test Charge</Description>
                          <TransactionDate>2021-12-14</TransactionDate>
                          <ServiceToDate>2021-11-30</ServiceToDate>
                          <ChargeCode>rentins</ChargeCode>
                          <CustomerID>t0020180</CustomerID>
                          <Amount>45.00</Amount>
                          <Comment>This is a test charge</Comment>
                          <PropertyPrimaryID>resca01</PropertyPrimaryID>
                        </Detail>
                      </Charge>
                    </Transactions>
                  </RTServiceTransactions>
                </RT_Customer>
              </Property>
            </ResidentTransactions>
          XML
          
          # left out cuz isn't the right number: <GLAccountNumber>4910-0000</GLAccountNumber>
        
        end
        
      end
    end
  end
end
