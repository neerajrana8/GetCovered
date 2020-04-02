module PolicyApplicationGroups
  class SourceXlsxParser < ActiveInteraction::Base
    string :xlsx_file_content

    def execute
      [ { name: 'A', last_name: 'B', unit: 1231 }, { name: 'C', last_name: 'D', unit: 122 } ]
    end
  end
end
