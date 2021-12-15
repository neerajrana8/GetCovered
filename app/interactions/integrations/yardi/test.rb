module Integrations
  module Yardi
    class Test < ActiveInteraction::Base
    
      string :call
      hash :params, default: {}, strip: false
      hash :diagnostics, default: {}, strip: false
      
      def execute
        integration = Integration.where(provider: 'yardi').first
        paramz = params.deep_symbolize_keys
        case call
          # RI no problems
          when "SystemBatch::GetVersionNumber"
            return Integrations::Yardi::SystemBatch::GetVersionNumber.run!(integration: integration, diagnostics: diagnostics, **paramz)
          when "RentersInsurance::GetInsurancePolicies"
            return Integrations::Yardi::RentersInsurance::GetInsurancePolicies.run!(integration: integration, property_id: 'resca01', diagnostics: diagnostics, **paramz)
          when "RentersInsurance::GetPropertyConfigurations"
            return Integrations::Yardi::RentersInsurance::GetPropertyConfigurations.run!(integration: integration, diagnostics: diagnostics, **paramz)
          when "RentersInsurance::GetUnitConfiguration"
            return Integrations::Yardi::RentersInsurance::GetUnitConfiguration.run!(integration: integration, property_id: 'resca01', diagnostics: diagnostics, **paramz)
          when "RentersInsurance::CustomerSearch"
            return Integrations::Yardi::RentersInsurance::CustomerSearch.run!(integration: integration, property_id: 'resca01', last_name: "DBon Jovi", diagnostics: diagnostics, **paramz)
          when "RentersInsurance::GetVersionNumber"
            return Integrations::Yardi::RentersInsurance::GetVersionNumber.run!(integration: integration, diagnostics: diagnostics, **paramz)
          # BAP no problems
          when "BillingAndPayments::GetVersionNumber"
            return Integrations::Yardi::BillingAndPayments::GetVersionNumber.run!(integration: integration, diagnostics: diagnostics, **paramz)
          when "BillingAndPayments::GetPropertyConfigurations"
            return Integrations::Yardi::BillingAndPayments::GetPropertyConfigurations.run!(integration: integration, diagnostics: diagnostics, **paramz)
          when "BillingAndPayments::GetResidentTransactions_Login", "BillingAndPayments::GetResidentTransactions"
            return Integrations::Yardi::BillingAndPayments::GetResidentTransactions.run!(integration: integration, property_id: 'resca01', **paramz)
          when "BillingAndPayments::GetChargeTypes_Login", "BillingAndPayments::GetChargeTypes"
            return Integrations::Yardi::BillingAndPayments::GetChargeTypes.run!(integration: integration, **paramz)
          # RI problems
          when "RentersInsurance::ImportInsurancePolicies"
            policy_hash = {
              Customer: {
                Identification: {
                  IDValue: "t0020164",
                  IDType: "Resident ID"
                },
                Name: {
                  FirstName: "Mike",
                  LastName: "Bon Jovi"
                }
              },
              Insurer: { Name: "Imaginary Carrier" },
              PolicyNumber: "IC000001",
              PolicyTitle: "Imaginary Policy #1",
              PolicyDetails: {
                EffectiveDate: "2021-11-01",
                ExpirationDate: "2022-10-31",
                IsRenew: "true",
                LiabilityAmount: "50000",
                Notes: "",
                IsRequiredForMoveIn: "false",
                IsPMInterestedParty: "true"
              }
            }
          
            policy_xml = <<~XML
              <RenterInsurance xmlns="http://yardi.com/RentersInsurance30" xmlns:MITS="http://my-company.com/namespace" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://yardi.com/RentersInsurance30 D:\YSI.NET_600822Plug-in8\Source\Interfaces\XSD\RentersInsurance.xsd">
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
              </RenterInsurance>
            XML
            return Integrations::Yardi::RentersInsurance::ImportInsurancePolicies.run!(integration: integration, property_id: 'resca01', policy_hash: policy_hash, change: false, diagnostics: diagnostics, **paramz)
          # BAP problems
          when "BillingAndPayments::ImportResidentTransactions_Login", "BillingAndPayments::ImportResidentTransactions"
            charge_hash = { # for QA
              Description: "Test Charge",
              TransactionDate: "2021-12-14",
              ServiceToDate: "2021-11-30",
              ChargeCode: "rentins",
              GLAccountNumber: "49750000",
              CustomerID: "t0020164",
              Amount: "125.00",
              Comment: "Renter's Insurance Charge",
              PropertyPrimaryID: "resca01"
            }
            #charge_hash = { # for est env
            #  Description: "Test Charge",
            #  TransactionDate: "2021-12-14",
            #  ServiceToDate: "2021-11-30",
            #  ChargeCode: "ins",
            #  CustomerID: "t0067659",
            #  Amount: "125.00",
            #  Comment: "Renter's Insurance Charge",
            #  PropertyPrimaryId: "resca01"
            #}
            return Integrations::Yardi::BillingAndPayments::ImportResidentTransactions.run!(integration: integration, charge_hash: charge_hash, diagnostics: diagnostics, **paramz)

          when "BillingAndPayments::ImportCharge_Login", "BillingAndPayments::ImportCharge"
            charge_xml = <<~XML
              <ResidentTransactions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://yardi.com/ResidentTransactions20" xsi:schemaLocation="http://yardi.com/ResidentTransactions20 C:\Users\kylec\Documents\_QA\_Interfaces\XSD\Itf_MITS_ResidentTransactions2.0.xsd">
                <Property>
                  <RT_Customer>
                    <RTServiceTransactions>
                      <Transactions>
                        <Charge>
                          <Detail>
                            <Description>Test Charge</Description>
                            <TransactionDate>2021-12-15</TransactionDate>
                            <ServiceToDate>2021-11-31</ServiceToDate>
                            <ChargeCode>rentins</ChargeCode>
                            <CustomerID>t0067659</CustomerID>
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
            
            charge_xml = <<~XML
              <YsiTran xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://yardi.com/ResidentTransactions20" xsi:schemaLocation="http://yardi.com/ResidentTransactions20 C:\Users\kylec\Documents\_QA\_Interfaces\XSD\Itf_MITS_ResidentTransactions2.0.xsd">
                <Charges>
                  <Charge>
                    <Amount>45.00</Amount>
                    <ChargeCodeId>rentins</ChargeCodeId>
                    <Date>2021-12-15T00:00:00</Date>
                    <Notes>This is a note on a charge</Note>
                    <PersonId>t0067659</PersonId>
                    <PostMonth>2022-01-01</PostMonth>
                    <PropertyId>resca01</PropertyId>
                    <Reference>Master Policy</Reference>
                    <UnitId>101</UnitId>
                  </Charge>
                </Charges>
              </YsiTran>
            XML
                    #<AccountId>??????????????????????????</AccountId>
            
            #      <GLAccountNumber>4910-0000</GLAccountNumber> left out cause it's the wrong number and the docs said to
            return Integrations::Yardi::BillingAndPayments::ImportCharge.run!(integration: integration, charge_xml: charge_xml, diagnostics: diagnostics, **paramz)
        end
      end
      
    end
  end
end
