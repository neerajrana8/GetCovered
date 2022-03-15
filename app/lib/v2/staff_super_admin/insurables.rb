# To generate response for insurables

module V2
  module StaffSuperAdmin
    class Insurables
      def initialize(insurables)
        @insurables = insurables
      end

      def response
        @response = []
        @insurables&.each do |i|
          @response.push(
            id: i.id,
            title: i.title,
            enabled: i.enabled,
            preferred_ho4: i.preferred_ho4,
            account_id: i.account_id,
            agency_id: i.account.agency_id,
            insurable_type_id: i.insurable_type_id,
            category: i.category,
            covered: i.covered,
            created_at: i.created_at,
            updated_at: i.updated_at,
            addresses: i.addresses,
            insurables: i.units.select{|u| u.enabled }
          )
        end
        @response
      end
    end
  end
end