# Report model
# file: +app/models/report.rb+

class Report < ApplicationRecord
  # Active Record Callbacks

  after_initialize :set_defaults

  # Relationships
  belongs_to :reportable,
             polymorphic: true,
             required: true

  enum duration: %w[day range]

  # Validations             
  validates_presence_of :data

  # For classic table reports with rows and headers in other cases - redefine this method
  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << headers

      data['rows'].each do |row|
        table_row = []
        headers.each do |attr|
          table_row << row["#{attr}"]
        end
        csv << table_row
      end
    end
  end

  private

  def set_defaults; end
end
