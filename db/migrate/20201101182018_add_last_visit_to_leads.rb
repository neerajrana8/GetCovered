class AddLastVisitToLeads < ActiveRecord::Migration[5.2]
  def change
    Lead.where(last_visit: nil).update_all('last_visit=created_at')
  end
end
