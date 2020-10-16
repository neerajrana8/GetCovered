class TrackingUrl < ApplicationRecord

  belongs_to :agency
  validates_presence_of :tracking_url, :landing_page, :campaign_source,
                        :campaign_medium, :campaign_name, :agency

  enum landing_page: {rent_garantee: 0, renters_insurance: 1, business_owners: 2}
end

