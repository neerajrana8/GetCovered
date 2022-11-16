module Integrations
  module Yardi
    module CommonData
      class GetRoommatePromotions < Integrations::Yardi::CommonData::Base
        string :property_id
        date :move_out_start, default: nil
        date :move_out_end, default: nil

        def execute
          super(**{
            YardiPropertyId: property_id,
            MoveOutFrom: move_out_start,
            MoveOutTo: move_out_end
          }.compact)
        end

        def retry_request?(prior_attempts, elapsed_seconds)
          prior_attempts < 3
        end
      end
    end
  end
end
