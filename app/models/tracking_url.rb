class TrackingUrl < ApplicationRecord

  has_many :leads

  belongs_to :agency
  validates_presence_of :landing_page, :campaign_source,
                        :campaign_medium, :campaign_name, :agency

  scope :not_deleted, -> { where(deleted: false) }

  enum landing_page: {rent_garantee: 0, renters_insurance: 1, business_owners: 2}

end

