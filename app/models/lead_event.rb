class LeadEvent < ApplicationRecord
  belongs_to :lead
  belongs_to :policy_type, optional: true

  after_create :update_lead_last_visit
  after_create :update_lead_last_visited_page, if: -> {self.data["last_visited_page"].present?}
  after_create :update_lead_agency, if: -> { self.agency_id.present? && self.agency_id != self.lead.agency_id }
  after_create :update_lead_phone, if: -> {self.data["phone"].present? && self.data["phone"] != self.lead.profile.contact_phone}
  after_create :update_lead_organization, if: -> {self.data["employer_name"].present? && self.data["employer_name"] != self.lead.profile.title}
  after_create :update_lead_job_title, if: -> {self.data["employment_description"].present? && self.data["employment_description"] != self.lead.profile.job_title}

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

  #check - seems that delayed on klaviyo on one event
  def update_lead_phone
    self.lead.profile.update(contact_phone: self.data["phone"])
  end

  def update_lead_organization
    self.lead.profile.update(title: self.data["employer_name"])
  end

  def update_lead_job_title
    self.lead.profile.update(job_title: self.data["employment_description"])
  end
end
