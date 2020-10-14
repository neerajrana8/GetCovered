class LeadEvent < ApplicationRecord
  belongs_to :lead

  after_create :update_lead_last_visit
  after_create :update_lead_last_visited_page, if: -> {self.data["last_visited_page"].present?}

  private

  def update_lead_last_visit
    self.lead.update(last_visit: self.created_at)
  end

  def update_lead_last_visited_page
    self.lead.update(last_page_visited: self.data["last_visited_page"])
  end
end
