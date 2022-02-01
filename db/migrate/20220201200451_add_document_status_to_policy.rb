class AddDocumentStatusToPolicy < ActiveRecord::Migration[6.1]
  def up
    add_column :policies, :document_status, :integer, :default => 0
    @policies = ::Policy.all
    @policies.each do |policy|
      policy.update document_status: "present" if policy.documents.count > 0
    end
  end
end
