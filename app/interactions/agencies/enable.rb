module Agencies
  class Enable < ActiveInteraction::Base
    object :agency

    def execute
      ActiveRecord::Base.transaction do
        enable_owner
        agency.update(enabled: true)
      end
    end

    private

    def enable_owner
      agency.owner&.update(enabled: true)
    end
  end
end
