module MasterPolicies
  class GenerateNextCoverageNumber < ActiveInteraction::Base
    string :master_policy_number

    def execute
      number = nil

      loop do
        number = "#{master_policy_number}_#{rand(36**16).to_s(36).upcase}"

        break unless Policy.exists?(number: number)
      end

      number
    end
  end
end
