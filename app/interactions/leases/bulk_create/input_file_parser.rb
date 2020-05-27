module Leases
  module BulkCreate
    class InputFileParser < ActiveInteraction::Base
      file :input_file

      def execute
        parsed_file
      end

      private

      def parsed_file
        @parsed_file ||= CSV.parse(input_file, headers: true)
      end
    end
  end
end
