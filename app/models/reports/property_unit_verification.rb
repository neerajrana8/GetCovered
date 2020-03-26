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
