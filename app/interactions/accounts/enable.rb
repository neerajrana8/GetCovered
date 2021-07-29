module Accounts
  class Enable < ActiveInteraction::Base
    object :account

    def execute
      ActiveRecord::Base.transaction do
        enable_owner
        account.update(enabled: true)
      end
    end

    private

    def enable_owner
      account.owner&.update(enabled: true)
    end
  end
end
