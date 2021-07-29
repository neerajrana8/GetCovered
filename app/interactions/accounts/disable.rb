module Accounts
  class Disable < ActiveInteraction::Base
    object :account

    def execute
      ActiveRecord::Base.transaction do
        disable_staffs
        account.update(enabled: false)
      end
    end

    private

    def disable_staffs
      account.staffs.update_all(enabled: false)
    end
  end
end
