# Master Policy Configuration model
# file: app/models/master_policy_configuration.rb
#

class MasterPolicyConfiguration < ApplicationRecord
  after_initialize :set_program_start_date, if: Proc.new { self.new_record? }

  belongs_to :carrier_policy_type
  belongs_to :configurable, polymorphic: true

  enum program_type: { auto: 0, choice: 1 }

  private

  def set_program_start_date
    self.program_start_date ||= (Time.current + 1.month).at_beginning_of_month
  end
end
