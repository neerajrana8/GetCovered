module Integrations
  module Yardi
    module RentersInsurance
      class ImportInsurancePolicies < Integrations::Yardi::RentersInsurance::Base
        string :property_id #getcov00
        object :policy, default: nil # a policy object (required unless policy_xml is supplied)
        string :policy_xml, default: nil #some xml
        
        def execute(**params)
          super(**params, **{
            YardiPropertyId: property_id,
            Policy: policy_xml || get_new_policy_xml
          }.compact)
        end
        
        
        def get_new_policy_xml
          
          unit_ip = policy.primary_insurable.integration_profile.where(integration: integration).take
          lease_ips = IntegrationProfile.references(:leases).includes(:lease).where(integration: integration, profileable_type: "Lease", external_context: "lease", profileable_id: policy.primary_insurable.leases.map{|l| l.id })
          user_ip = policy.primary_user.integration_profile.where(integration: integration, profileable_type: "User", external_context: lease_ips.map{|lip| "tenant_#{lip.external_id}" }).take
          
          <<~XML
            <RenterInsurance xmlns="http://yardi.com/RentersInsurance30" xmlns:MITS="http://my-company.com/namespace" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://yardi.com/RentersInsurance30 D:\YSI.NET_600822Plug-in8\Source\Interfaces\XSD\RentersInsurance.xsd">
              <InsurancePolicy Type="new">
                <Customer>
                  <MITS:Identification IDType="Resident ID">
                    <MITS:IDValue>#{user_ip.external_id}</MITS:IDValue>
                  </MITS:Identification>
                  <MITS:Name>
                    <MITS:FirstName>#{policy.primary_user.profile.first_name}</MITS:FirstName>
                    <MITS:LastName>#{policy.primary_user.profile.last_name}</MITS:LastName>
                  </MITS:Name>
                </Customer>
                <Insurer>
                  <Name>#{policy.carrier.title}</Name>
                </Insurer>
                <PolicyNumber>#{policy.number}</PolicyNumber>
                <PolicyTitle>#{policy.policy_type.title} Policy ##{policy.number}</PolicyTitle>
                <PolicyDetails>
                  <EffectiveDate>#{policy.effective_date.to_s}</EffectiveDate>
                  <ExpirationDate>#{policy.expiration_date.to_s}</ExpirationDate>
                  <IsRenew>#{policy.auto_renew ? 'true' : 'false'}</IsRenew>
                  <LiabilityAmount>#{policy.get_liability / 100}</LiabilityAmount>
                  <Notes></Notes>
                  <IsRequiredForMoveIn>false</IsRequiredForMoveIn>
                  <IsPMInterestedParty>#{policy.account_id == integration.integratable_id && integration.integratable_type == 'Account'}</IsPMInterestedParty>
                </PolicyDetails>
              </InsurancePolicy>
            </RenterInsurance>
          XML
          
          # MOOSE WARNING question: what should policy title be???
          # MOOSE WARNING question: wtf to do with "IsRequiredForMoveIn"?
        end
        
        
        
        
        def example_new_policy_xml
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
        
        def example_changed_policy_xml
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
end
