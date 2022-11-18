module Integrations
  module Yardi
    module ResidentData
      class GetRoommatePromotions < Integrations::Yardi::ResidentData::Base
        string :property_id
        date :move_out_from, default: nil
        date :move_out_to, default: nil

        def execute
          super(**{
            YardiPropertyId: property_id,
            MoveOutFrom: move_out_from&.to_date&.to_s,
            MoveOutTo: move_out_to&.to_date&.to_s
          }.compact)
        end

        def retry_request?(prior_attempts, elapsed_seconds)
          prior_attempts < 3
        end
      end
    end
  end
end
