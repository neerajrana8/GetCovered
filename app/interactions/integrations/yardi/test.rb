module Integrations
  module Yardi
    class Test < ActiveInteraction::Base
    
      string :call
      hash :params, default: {}, strip: false
      
      def execute
        integration = Integration.where(provider: 'yardi').first
        paramz = params.deep_symbolize_keys
        case call
          # RI no problems
          when "SystemBatch::GetVersionNumber"
            return Integrations::Yardi::SystemBatch::GetVersionNumber.run!(integration: integration, **paramz)
          when "RentersInsurance::GetInsurancePolicies"
            return Integrations::Yardi::RentersInsurance::GetInsurancePolicies.run!(integration: integration, property_id: 'resca01', **paramz)
          when "RentersInsurance::GetPropertyConfigurations"
            return Integrations::Yardi::RentersInsurance::GetPropertyConfigurations.run!(integration: integration, **paramz)
          when "RentersInsurance::GetUnitConfiguration"
            return Integrations::Yardi::RentersInsurance::GetUnitConfiguration.run!(integration: integration, property_id: 'resca01', **paramz)
          when "RentersInsurance::CustomerSearch"
            return Integrations::Yardi::RentersInsurance::CustomerSearch.run!(integration: integration, property_id: 'resca01', last_name: "DBon Jovi", **paramz)
          when "RentersInsurance::GetVersionNumber"
            return Integrations::Yardi::RentersInsurance::GetVersionNumber.run!(integration: integration, **paramz)
          # BAP no problems
          when "BillingAndPayments::GetVersionNumber"
            return Integrations::Yardi::BillingAndPayments::GetVersionNumber.run!(integration: integration, **paramz)
          when "BillingAndPayments::GetPropertyConfigurations"
            return Integrations::Yardi::BillingAndPayments::GetPropertyConfigurations.run!(integration: integration, **paramz)
          #when "BillingAndPayments::GetResidentTransactions_Login", "BillingAndPayments::GetResidentTransactions"
          #  return Integrations::Yardi::BillingAndPayments::GetResidentTransactions.run!(integration: integration, property_id: 'resca01', **paramz)
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
            return Integrations::Yardi::RentersInsurance::ImportInsurancePolicies.run!(integration: integration, property_id: 'resca01', policy_hash: policy_hash, change: false, **paramz)
          # BAP problems
          when "BillingAndPayments::ImportResidentTransactions_Login", "BillingAndPayments::ImportResidentTransactions"
            charge_hash = { # for QA
              Description: "QA Test Charge",
              TransactionDate: "2021-12-14",
              ServiceToDate: "2021-12-30",
              ChargeCode: "rentins",
              GLAccountNumber: "49750000",
              CustomerID: "t0020164",
              Amount: "102.00",
              Comment: "Test Charge for QA",
              PropertyPrimaryID: "resca01"
            }
            return Integrations::Yardi::BillingAndPayments::ImportResidentTransactions.run!(integration: integration, charge_hash: charge_hash, **paramz)
        end
      end
      
    end
  end
end
