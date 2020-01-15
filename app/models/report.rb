# Report model
# file: +app/models/report.rb+

class Report < ApplicationRecord
  # Active Record Callbacks
  after_initialize :initialize_report

  # Relationships
  belongs_to :reportable,
    polymorphic: true,
    required: true

  # Enum Options
  enum format: %w[coverage activity]

  enum duration: %w[day range]

  # Validations             
  validates_presence_of :format, :data

  private

  def initialize_report
    self.duration ||= 'day'
    self.format   ||= 'coverage'

    self.data ||= {}
    case self.format
    when 'coverage'
      self.data['unit_count']                    ||= 0
      self.data['occupied_count']                ||= 0
      self.data['covered_count']                 ||= 0
      self.data['master_policy_covered_count']   ||= 0
      self.data['policy_covered_count']          ||= 0
      self.data['policy_internal_covered_count'] ||= 0
      self.data['policy_external_covered_count'] ||= 0
      self.data['cancelled_policy_count']        ||= 0
    end
  end
end
