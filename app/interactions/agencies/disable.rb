module Agencies
  class Disable < ActiveInteraction::Base
    object :agency

    def execute
      ActiveRecord::Base.transaction do
        disable_staffs
        agency.update(enabled: false)
      end
    end

    private

    def disable_staffs
      agency.staffs.update_all(enabled: false)
    end
  end
end
