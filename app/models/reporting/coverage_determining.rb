module Reporting
  module CoverageDetermining
    extend ActiveSupport::Concern
    
    COVERAGE_DETERMINANTS = { # are we counting units whose lessees are all covered based on exact User matches, equivalent numbers, or just any active policy?
      any: 0,
      exact: 1
    }.freeze
    
    COVERAGE_STATUSES = {
      none: 0,
      master: 1,
      external: 2,
      internal_and_external: 3, # unit is covered only when users on policies of both types are combined (i.e. you need both i and e to get that you're covered)
      internal: 4,
      internal_or_external: 5 # unit is covered completely by internal policies, and also covered completely by external policies (i.e. choose i or e and you are covered either way)
    }.freeze
    
    COVERAGE_STATUSES_ORDER = [:internal_or_external, :internal, :external, :internal_and_external, :master, :none].freeze
    
    COVERAGE_DETERMINANT_ENUM_INFO = {
      enum_values: [COVERAGE_DETERMINANTS.keys.map{|x| x.to_s }],
      format: [
        "Unit Match",
        "Count Match",
        "Exact Match"
      ]
    }
    
  end # end module CoverageDetermining
end # end module Reporting
