# frozen_string_literal: true

class TrackingUrl < ApplicationRecord
  RENT_GUARANTEE = 'rent_guarantee'
  RENTERS_INSURANCE = 'renters_insurance'
  BUSINESS_OWNERS = 'business_owners'

  has_many :leads

  belongs_to :agency
  validates_presence_of :landing_page, :campaign_source,
                        :campaign_medium, :campaign_name, :agency

  scope :not_deleted, -> { where(deleted: false) }

end

