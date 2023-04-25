module SpecialStatusable
  extend ActiveSupport::Concern

  SPECIAL_STATUSES = {
    none: 0,
    affordable: 1
  }.freeze
  
end
