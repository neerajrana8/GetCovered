# == Schema Information
#
# Table name: reports
#
#  id              :bigint           not null, primary key
#  duration        :integer
#  range_start     :datetime
#  range_end       :datetime
#  data            :jsonb
#  reportable_type :string
#  reportable_id   :bigint
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  type            :string
#
module Reports
  class PropertyUnitVerification < ::Report
    NAME = 'Property unit verification'.freeze

    def generate
      units&.each do |unit|
        self.data['rows'] << {
          'location_address' => unit.primary_address&.full,
          'unit' => unit.title
        }
      end
      self
    end

    def column_names
      {
        'location_address' => 'Location Address',
        'unit' => 'Unit #'
      }
    end

    def headers
      %w[location_address unit]
    end

    private

    def units
      if reportable.is_a?(Insurable)
        reportable.units&.select{|unit| unit.covered == true}
      else
        reportable.insurables.units.where(covered: true)
      end
    end

    def set_defaults
      self.data ||= { rows:[] }
    end
  end
end
