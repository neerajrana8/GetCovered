class LeadEvent < ApplicationRecord
  belongs_to :lead

  after_create :update_lead_last_visit
  after_create :update_lead_last_visited_page, if: -> {self.data["last_visited_page"].present?}
  after_create :update_lead_agency, if: -> { self.agency_id.present? && self.agency_id != self.lead.agency_id }

  private

  def update_lead_last_visit
    self.lead.update(last_visit: self.created_at)
  end

  def update_lead_last_visited_page
    self.lead.update(last_visited_page: self.data["last_visited_page"])
  end

  # TODO : need to be removed after moving agency on ui
  def update_lead_agency
    self.lead.update(agency_id: self.agency_id)
  end
end
