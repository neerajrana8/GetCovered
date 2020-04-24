class AddPolicyGroupQuoteToPolicyQuotes < ActiveRecord::Migration[5.2]
  def change
    add_reference :policy_quotes, :policy_group_quote
  end
end
