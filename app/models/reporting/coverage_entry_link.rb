
module Reporting
  class CoverageEntryLink < ApplicationRecord
    self.table_name = "reporting_coverage_entry_links"

    belongs_to :parent,
      class_name: "Reporting::CoverageEntry",
      inverse_of: :links,
      foreign_key: :parent_id
    
    belongs_to :child,
      class_name: "Reporting::UnitCoverageEntry",
      inverse_of: :links,
      foreign_key: :child_id
    
    validates_uniqueness_of :child_id, scope: [:parent_id]
    
    def self.try_insert_all(wut)
      wut.blank? ? nil : insert_all(wut)
    end

  end # end class
end
