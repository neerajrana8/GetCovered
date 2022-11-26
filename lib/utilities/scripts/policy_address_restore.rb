# Utils
module Utilities
  module Scripts
    # PolicyAddressRestore
    module PolicyAddressRestore
      def restore_policy_addreses
        policies = Policy.where(policy_in_system: false, address: nil)
        policies.each do |p|
          address_string = p.users.where(primary: true).first&.address&.full
          p.update_columns(address: address_string)
        end
      end
    end
  end
end
