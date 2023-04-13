class AddReportable2ToReports < ActiveRecord::Migration[6.1]
  def change
    # NOTE: some reports like ChargePushReport require multiple reportables at once (account and community in this case)
    add_reference :reports, :reportable2, polymorphic: true
  end
end
