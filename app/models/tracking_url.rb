# frozen_string_literal: true

class TrackingUrl < ApplicationRecord
  has_many :leads

  belongs_to :agency
  validates_presence_of :landing_page, :agency, :campaign_name

  scope :not_deleted, -> { where(deleted: false) }
  scope :deleted, -> { where(deleted: true) }

  def branding_url
    "https://#{self.agency.branding_profiles.first.url}"
  end

  def form_url
    "#{branding_url}/#{self.landing_page}"
  end

end

