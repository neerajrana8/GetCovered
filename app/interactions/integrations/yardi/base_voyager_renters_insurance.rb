module Integrations
  module Yardi
    class BaseVoyagerRentersInsurance < Integrations::Yardi::BaseVoyager
      def type
        "renters_insurance"
      end
    end
  end
end
