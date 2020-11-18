#
# AgencyConfiePolicy Concern
# file: app/models/concerns/agency_confie_policy.rb

module AgencyConfiePolicy
  extend ActiveSupport::Concern

  included do
    after_save :inform_confie_of_policy,
      if: Proc.new{|obj| obj.saved_change_to_attribute?('status') && obj.is_active? && !obj.was_active? && obj.agency_id == ConfieService.agency_id }
  end

  def inform_confie_of_policy
  end
  
end
