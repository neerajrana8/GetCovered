module Policies
  class UpdateDocuments < ActiveInteraction::Base
    object :policy

    def execute
      return unless policy.in_system?

      ActiveRecord::Base.transaction do
        policy.documents.purge
        policy.send("#{policy.carrier.integration_designation}_issue_policy")
      end
    end
  end
end
