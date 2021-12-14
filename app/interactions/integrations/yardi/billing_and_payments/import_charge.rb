module Integrations
  module Yardi
    module BillingAndPayments
      class ImportCharge < Integrations::Yardi::BillingAndPayments::Base
      
        object :invoice, default: nil     # the invoice to make a charge for
        string :charge_xml, default: nil  # optionally, provide charge xml directly
        
        def execute
          super(**{
            Charges: charge_xml || get_new_charge_xml # docs say TransactionXml
          }.compact)
        end
        
        def action # override action to add the goofy "_Login"
          "ImportCharge_Login"
        end
        
        def get_new_charge_xml
          
          #  <RT_Customer><RTServiceTransactions><Transactions>
          # </Transactions></RTServiceTransactions></RT_Customer>
          
          
          return <<~XML
            <Charge>
              <Detail>
                <Description>Test Charge</Description>
                <TransactionDate>2021-12-15</TransactionDate>
                <ServiceFromDate>2021-11-01</ServiceFromDate>
                <ServiceToDate>2021-11-31</ServiceToDate>
                <ChargeCode>admin</ChargeCode>
                <GLAccountNumber>4910-0000</GLAccountNumber>
                <CustomerID>t0067659</CustomerID>
                <Amount>45.00</Amount>
                <Comment>This is a test charge</Comment>
                <PropertyPrimaryID>getcov01</PropertyPrimaryID>
              </Detail>
            </Charge>
          XML
        
          <<~XML
            <Charge>
              <Detail>
                <Description>Charge1</Description>
                <TransactionDate>2018-12-21</TransactionDate>
                <ServiceToDate>2017-01-01</ServiceToDate>
                <ChargeCode>admin</ChargeCode>
                <GLAccountNumber>4910-0000</GLAccountNumber>
                <CustomerID>t0002172</CustomerID>
                <Amount>18.00</Amount>
                <Comment>Charge from web service</Comment>
                <PropertyPrimaryID>ares319</PropertyPrimaryID>
                <AdditionalFields Type="DisplayType" Value="Condo International" />
              </Detail>
            </Charge>
          XML
        end
        
      end
    end
  end
end
