module Integrations
  module Yardi
    class Test < ActiveInteraction::Base
    
      string :call
      hash :diagnostics, default: {}
      
      def execute
        integration = Integration.where(provider: 'yardi').first
        case call
          # RI no problems
          when "RentersInsurance::GetInsurancePolicies"
            return Integrations::Yardi::RentersInsurance::GetInsurancePolicies.run!(integration: integration, property_id: 'getcov01', diagnostics: diagnostics)
          when "RentersInsurance::GetPropertyConfigurations"
            return Integrations::Yardi::RentersInsurance::GetPropertyConfigurations.run!(integration: integration, diagnostics: diagnostics)
          when "RentersInsurance::GetUnitConfiguration"
            return Integrations::Yardi::RentersInsurance::GetUnitConfiguration.run!(integration: integration, property_id: 'getcov01', diagnostics: diagnostics)
          when "RentersInsurance::CustomerSearch"
            return Integrations::Yardi::RentersInsurance::CustomerSearch.run!(integration: integration, property_id: 'getcov01', first_name: "Ricky", last_name: "Woods", diagnostics: diagnostics)
          when "RentersInsurance::GetVersionNumber"
            return Integrations::Yardi::RentersInsurance::GetVersionNumber.run!(integration: integration, diagnostics: diagnostics)
          # BAP no problems
          when "BillingAndPayments::GetVersionNumber"
            return Integrations::Yardi::BillingAndPayments::GetVersionNumber.run!(integration: integration, diagnostics: diagnostics)
          when "BillingAndPayments::GetPropertyConfigurations"
            return Integrations::Yardi::BillingAndPayments::GetPropertyConfigurations.run!(integration: integration, diagnostics: diagnostics)
          when "BillingAndPayments::GetResidentTransactions_Login", "BillingAndPayments::GetResidentTransactions"
            return Integrations::Yardi::BillingAndPayments::GetResidentTransactions.run!(integration: integration, property_id: 'getcov02')
          when "BillingAndPayments::GetChargeTypes_Login", "BillingAndPayments::GetChargeTypes"
            return Integrations::Yardi::BillingAndPayments::GetChargeTypes.run!(integration: integration)
          # RI problems
          when "RentersInsurance::ImportInsurancePolicies"
            policy_xml = <<~XML
              <InsurancePolicy Type="new">
                <Customer>
                  <MITS:Identification IDType="Resident ID">
                    <MITS:IDValue>t0067659</MITS:IDValue>
                  </MITS:Identification>
                  <MITS:Name>
                    <MITS:FirstName>Kathy</MITS:FirstName>
                    <MITS:LastName>Norman</MITS:LastName>
                  </MITS:Name>
                </Customer>
                <Insurer>
                  <Name>Imaginary Carrier</Name>
                </Insurer>
                <PolicyNumber>IC000001</PolicyNumber>
                <PolicyTitle>Imaginary Policy #1</PolicyTitle>
                <PolicyDetails>
                  <EffectiveDate>2021-01-01</EffectiveDate>
                  <ExpirationDate>2021-06-30</ExpirationDate>
                  <IsRenew>true</IsRenew>
                  <LiabilityAmount>50000</LiabilityAmount>
                  <Notes></Notes>
                  <IsRequiredForMoveIn>false</IsRequiredForMoveIn>
                  <IsPMInterestedParty>true</IsPMInterestedParty>
                </PolicyDetails>
              </InsurancePolicy>
            XML
            return Integrations::Yardi::RentersInsurance::ImportInsurancePolicies.run!(integration: integration, property_id: 'getcov02', policy_xml: policy_xml, diagnostics: diagnostics)
          # BAP problems
          when "BillingAndPayments::ImportCharge_Login", "BillingAndPayments::ImportCharge"
            charge_xml = <<~XML
              <ResidentTransactions xmins="">
                <Property>
                  <RT_Customer>
                    <RTServiceTransactions>
                      <Transactions>
                        <Charge>
                          <Detail>
                            <Description>Test Charge</Description>
                            <TransactionDate>2021-12-15</TransactionDate>
                            <ServiceToDate>2021-11-31</ServiceToDate>
                            <ChargeCode>insur</ChargeCode>
                            <CustomerID>t0067659</CustomerID>
                            <Amount>45.00</Amount>
                            <Comment>This is a test charge</Comment>
                            <PropertyPrimaryID>getcov02</PropertyPrimaryID>
                          </Detail>
                        </Charge>
                      </Transactions>
                    </RTServiceTransactions>
                  </RT_Customer>
                </Property>
              </ResidentTransactions>
            XML
            #      <GLAccountNumber>4910-0000</GLAccountNumber> left out cause it's the wrong number and the docs said to
            return Integrations::Yardi::BillingAndPayments::ImportCharge.run!(integration: integration, charge_xml: charge_xml, diagnostics: diagnostics)
        end
      end
      
    end
  end
end
