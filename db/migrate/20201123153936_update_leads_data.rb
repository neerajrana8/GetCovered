class UpdateLeadsData < ActiveRecord::Migration[5.2]
  def up
    Lead.where(agency_id: nil).update_all(agency_id: 1)
    Lead.where(last_visit: nil).update_all(last_visit: :created_at)
    Lead.where(last_visited_page: nil).update_all(last_visited_page: "Landing Page")

    LeadEvent.all.each do |lead_event|
      data = lead_event.data

      if data["policy_type_id"].blank?
        data["policy_type_id"] = lead_event.lead.last_visited_page.include?('Section') ? 1 : 5
      end
      lead_event.update(data: data, policy_type_id: data["policy_type_id"])
    end
  end

end
