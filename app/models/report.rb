# == Schema Information
#
# Table name: reports
#
#  id               :bigint           not null, primary key
#  duration         :integer
#  range_start      :datetime
#  range_end        :datetime
#  data             :jsonb
#  reportable_type  :string
#  reportable_id    :bigint
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  type             :string
#  reportable2_id   :bigint
#  reportable2_type :string
#

class Report < ApplicationRecord
  # Active Record Callbacks

  after_initialize :set_defaults

  # Relationships
  belongs_to :reportable,
             polymorphic: true,
             optional: true

  belongs_to :reportable2,
    polymorphic: true,
    optional: true

  enum duration: %w[day range]

  # Validations
  validates_presence_of :data

  def name
    self.class::NAME
  end

  def available_formats
    ['csv']
  end

  # Generates data for this report without updating the object. It's useful when you only want to return the data
  # without saving it in the database, for example:
  #   new_report = Report::Activity.new(reportable: Agency.last)
  #   new_report.generate
  #   print new_report.data # show or process the result data
  #   new_report.save if save_report? # save or not this report
  # P.S. Warning! Method mutates the object.
  def generate
    raise NotImplementedError
  end

  # For classic table reports with rows and headers in other cases - redefine this method
  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << headers.map{|header| column_names[header]}

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
