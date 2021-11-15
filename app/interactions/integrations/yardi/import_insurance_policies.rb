module Integrations
  module Yardi
    class ImportInsurancePolicies < Integrations::Yardi::BaseVoyagerRentersInsurance
      string :property_id #getcov00
      policy :string # some xml
      def execute
        throw "NOT ALLOWED RIGHT NOW BRO"
        super(**{
          YardiPropertyId: property_id,
          Policy: policy
        }.compact)
      end
      
      
      def get_new_policy_xml
        <<~XML
          <InsurancePolicy Type="new">
            <Customer>
              <MITS:Identification IDType="Resident ID">
                <MITS:IDValue>t0016870</MITS:IDValue>
              </MITS:Identification>
              <MITS:Name>
                <MITS:FirstName>Christine</MITS:FirstName>
                <MITS:LastName>Parker</MITS:LastName>
              </MITS:Name>
            </Customer>
            <Insurer>
              <Name>Assurant</Name>
            </Insurer>
            <PolicyNumber>RL 100199607</PolicyNumber>
            <PolicyTitle>New Policy</PolicyTitle>
            <PolicyDetails>
              <EffectiveDate>2013-09-01</EffectiveDate>
              <ExpirationDate>2014-09-01</ExpirationDate>
              <IsRenew>false</IsRenew>
              <LiabilityAmount>50000</LiabilityAmount>
              <Notes>Notes</Notes>
              <IsRequiredForMoveIn>true</IsRequiredForMoveIn>
              <IsPMInterestedParty>true</IsPMInterestedParty>
            </PolicyDetails>
          </InsurancePolicy>
        XML
      end
      
      def get_new_policy_xml
        <<~XML
          <InsurancePolicy Type="change">
          <Customer>
            <MITS:Identification>
            <MITS:IDValue>t0000909</MITS:IDValue>
          </MITS:Identification>
          <MITS:Name>
            <MITS:NamePrefix></MITS:NamePrefix>
            <MITS:FirstName>Howard</MITS:FirstName>
            <MITS:MiddleName></MITS:MiddleName>
            <MITS:LastName>Long</MITS:LastName>
          </MITS:Name>
          </Customer>
          <Insurer>
            <Name>ACME Insurance Company</Name>
          </Insurer>
          <PolicyNumber>HO6-RI333333-N</PolicyNumber>
          <PolicyTitle>Update Policy</PolicyTitle>
          <PolicyDetails>
            <EffectiveDate>2013-09-01</EffectiveDate>
            <ExpirationDate>2014-09-01</ExpirationDate>
            <IsRenew>false</IsRenew>
            <LiabilityAmount>50000</LiabilityAmount>
            <Notes>Notes</Notes>
            <IsRequiredForMoveIn>true</IsRequiredForMoveIn>
            <IsPMInterestedParty>true</IsPMInterestedParty>
            <IsPetEndorsement>false</IsPetEndorsement>
            <PolicyId>23</PolicyId>
          </PolicyDetails>
          </InsurancePolicy>
        XML
      end
      
    end
  end
end
